// Package uploads serves resumable uploads (tus 1.0, ADR 0011) at
// /api/v1/uploads/ and turns each completed upload into a drive node.
package uploads

import (
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"
	"github.com/tus/tusd/v2/pkg/filestore"
	tusd "github.com/tus/tusd/v2/pkg/handler"
	"github.com/tus/tusd/v2/pkg/memorylocker"
	expslog "golang.org/x/exp/slog"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

const (
	BasePath = "/api/v1/uploads/"
	// NodeHeader carries the id of the created node in the final PATCH response.
	NodeHeader = "Alcove-Node-Id"

	// maxChunk bounds a single PATCH body; clients send smaller chunks.
	maxChunk = 64 << 20
	// staleAfter: incomplete uploads untouched for this long are deleted.
	staleAfter = 24 * time.Hour

	metaFilename = "filename"
	metaParent   = "parent"
	metaOwner    = "owner"

	// errQuota prefixes quota rejections so clients can tell them apart.
	errQuota = "ERR_QUOTA_EXCEEDED"
)

type ownerKey struct{}

type service struct {
	app   core.App
	store filestore.FileStore
	tus   http.Handler
}

// Register mounts the tus endpoint and the hourly cleanup job. behindProxy
// makes upload URLs (Location) honor X-Forwarded-Proto/Host, so they stay
// https behind Caddy; only enable it when a trusted proxy is the only way in.
func Register(app core.App, behindProxy bool) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		s, err := newService(se.App, behindProxy)
		if err != nil {
			return err
		}
		// Explicit methods: a method-less pattern would conflict with the SPA's GET catch-all.
		for _, method := range []string{http.MethodPost, http.MethodHead, http.MethodPatch, http.MethodDelete} {
			se.Router.Route(method, BasePath+"{path...}", s.serve).
				Bind(apis.RequireAuth("users"), apis.BodyLimit(maxChunk))
		}
		return se.Next()
	})

	app.Cron().MustAdd("alcoveStaleUploads", "17 * * * *", func() {
		if err := removeStale(uploadsDir(app), time.Now().Add(-staleAfter)); err != nil {
			app.Logger().Error("cleanup of stale uploads failed", "error", err)
		}
	})
}

// Partial uploads always live on local disk, even when final storage is S3.
func uploadsDir(app core.App) string { return filepath.Join(app.DataDir(), "uploads") }

func newService(app core.App, behindProxy bool) (*service, error) {
	dir := uploadsDir(app)
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return nil, err
	}
	s := &service{app: app, store: filestore.New(dir)}

	composer := tusd.NewStoreComposer()
	s.store.UseIn(composer)
	memorylocker.New().UseIn(composer)

	h, err := tusd.NewHandler(tusd.Config{
		StoreComposer:             composer,
		BasePath:                  BasePath,
		MaxSize:                   drive.MaxFileSize,
		RespectForwardedHeaders:   behindProxy,
		DisableDownload:           true,
		DisableConcatenation:      true,
		Cors:                      &tusd.CorsConfig{Disable: true},                      // PocketBase handles CORS
		Logger:                    expslog.New(expslog.NewTextHandler(io.Discard, nil)), // per-request logs are noise
		PreUploadCreateCallback:   s.preCreate,
		PreFinishResponseCallback: s.preFinish,
	})
	if err != nil {
		return nil, err
	}
	// tusd routes on paths relative to BasePath.
	s.tus = http.StripPrefix(strings.TrimSuffix(BasePath, "/"), h)
	return s, nil
}

// serve authenticates the request, checks that an existing upload belongs to
// the caller, then delegates to tusd.
func (s *service) serve(e *core.RequestEvent) error {
	owner := e.Auth.Id
	ctx := context.WithValue(e.Request.Context(), ownerKey{}, owner)

	if id := strings.Trim(strings.TrimPrefix(e.Request.URL.Path, BasePath), "/"); id != "" {
		if !s.ownedBy(ctx, id, owner) {
			return e.NotFoundError("", nil)
		}
	}
	s.tus.ServeHTTP(e.Response, e.Request.WithContext(ctx))
	return nil
}

func (s *service) ownedBy(ctx context.Context, id, owner string) bool {
	up, err := s.store.GetUpload(ctx, id)
	if err != nil {
		return false
	}
	info, err := up.GetInfo(ctx)
	return err == nil && info.MetaData[metaOwner] == owner
}

func reject(code, msg string, status int) (tusd.HTTPResponse, tusd.FileInfoChanges, error) {
	return tusd.HTTPResponse{}, tusd.FileInfoChanges{}, tusd.NewError(code, msg, status)
}

// preCreate validates the upload before any byte is stored and keeps only
// sanitized metadata (plus the owner).
func (s *service) preCreate(hook tusd.HookEvent) (tusd.HTTPResponse, tusd.FileInfoChanges, error) {
	owner, _ := hook.Context.Value(ownerKey{}).(string)
	if owner == "" {
		return reject("ERR_UNAUTHORIZED", "authentication required", http.StatusUnauthorized)
	}
	up := hook.Upload
	if up.SizeIsDeferred {
		return reject("ERR_LENGTH_REQUIRED", "Upload-Length is required", http.StatusBadRequest)
	}

	name := strings.TrimSpace(up.MetaData[metaFilename])
	if !drive.ValidName(name) {
		return reject("ERR_INVALID_NAME", "invalid file name", http.StatusBadRequest)
	}
	parent := up.MetaData[metaParent]
	if err := checkParent(s.app, owner, parent); err != nil {
		return reject("ERR_INVALID_PARENT", err.Error(), http.StatusBadRequest)
	}
	if err := drive.CheckQuota(s.app, owner, up.Size, ""); err != nil {
		if drive.IsQuotaError(err) {
			return reject(errQuota, "not enough storage space left", http.StatusRequestEntityTooLarge)
		}
		return reject("ERR_INTERNAL", "could not check the quota", http.StatusInternalServerError)
	}

	return tusd.HTTPResponse{}, tusd.FileInfoChanges{MetaData: tusd.MetaData{
		metaOwner: owner, metaFilename: name, metaParent: parent,
	}}, nil
}

// checkParent: empty (root) or a non-trashed folder of the same owner.
func checkParent(app core.App, owner, parent string) error {
	if parent == "" {
		return nil
	}
	p, err := app.FindRecordById(drive.Collection, parent)
	if err != nil || p.GetString("owner") != owner {
		return errors.New("parent folder not found")
	}
	if p.GetString("kind") != drive.KindFolder || !p.GetDateTime("trashed_at").IsZero() {
		return errors.New("parent is not an active folder")
	}
	return nil
}

// preFinish runs once all bytes are stored: it creates the node (the drive
// hooks compute size, mime and sha256), then deletes the partial upload.
func (s *service) preFinish(hook tusd.HookEvent) (tusd.HTTPResponse, error) {
	meta := hook.Upload.MetaData
	owner, parent := meta[metaOwner], meta[metaParent]

	// The parent may have been trashed or deleted during a long upload.
	if err := checkParent(s.app, owner, parent); err != nil {
		return tusd.HTTPResponse{}, tusd.NewError("ERR_INVALID_PARENT", err.Error(), http.StatusConflict)
	}

	node, err := s.createNode(owner, parent, meta[metaFilename], hook.Upload.Storage[filestore.StorageKeyPath])
	if err != nil {
		if drive.IsQuotaError(err) {
			// Other uploads filled the quota meanwhile: discard this one.
			s.discard(hook)
			return tusd.HTTPResponse{}, tusd.NewError(errQuota, "not enough storage space left", http.StatusRequestEntityTooLarge)
		}
		s.app.Logger().Error("upload finalization failed", "upload", hook.Upload.ID, "error", err)
		return tusd.HTTPResponse{}, tusd.NewError("ERR_FINALIZE", "could not store the file", http.StatusInternalServerError)
	}
	s.discard(hook)
	return tusd.HTTPResponse{Header: tusd.HTTPHeader{NodeHeader: node.Id}}, nil
}

// discard deletes an upload's partial data.
func (s *service) discard(hook tusd.HookEvent) {
	if up, err := s.store.GetUpload(hook.Context, hook.Upload.ID); err == nil {
		if err := s.store.AsTerminatableUpload(up).Terminate(hook.Context); err != nil {
			s.app.Logger().Warn("could not delete upload data", "upload", hook.Upload.ID, "error", err)
		}
	}
}

func (s *service) createNode(owner, parent, filename, binPath string) (*core.Record, error) {
	col, err := s.app.FindCollectionByNameOrId(drive.Collection)
	if err != nil {
		return nil, err
	}
	// Retry once on a name collision created by a concurrent upload.
	for attempt := 0; ; attempt++ {
		name, err := drive.AvailableName(s.app, owner, parent, filename)
		if err != nil {
			return nil, err
		}
		file, err := filesystem.NewFileFromPath(binPath)
		if err != nil {
			return nil, err
		}
		file.OriginalName = name

		node := core.NewRecord(col)
		node.Set("owner", owner)
		node.Set("parent", parent)
		node.Set("name", name)
		node.Set("kind", drive.KindFile)
		node.Set("blob", file)
		err = s.app.Save(node)
		if err == nil {
			return node, nil
		}
		if attempt >= 1 || drive.IsQuotaError(err) {
			return nil, fmt.Errorf("save node: %w", err)
		}
	}
}

// removeStale deletes tus files (.bin/.info) not modified since cutoff. The
// directory is flat; os.Root keeps removals inside it (no symlink escapes).
func removeStale(dir string, cutoff time.Time) error {
	root, err := os.OpenRoot(dir)
	if err != nil {
		if errors.Is(err, fs.ErrNotExist) {
			return nil
		}
		return err
	}
	defer func() { _ = root.Close() }()

	entries, err := fs.ReadDir(root.FS(), ".")
	if err != nil {
		return err
	}
	var errs []error
	for _, entry := range entries {
		info, err := entry.Info()
		if err != nil || !info.Mode().IsRegular() || !info.ModTime().Before(cutoff) {
			continue
		}
		if err := root.Remove(entry.Name()); err != nil {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}
