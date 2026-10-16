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
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"
	"github.com/tus/tusd/v2/pkg/filestore"
	tusd "github.com/tus/tusd/v2/pkg/handler"
	"github.com/tus/tusd/v2/pkg/memorylocker"
	expslog "golang.org/x/exp/slog"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/takeout"
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
	metaPurpose  = "purpose"
	// purposeImport: a Google Takeout archive, kept as a temporary import file (ADR 0030).
	purposeImport = "import"

	// errQuota prefixes quota rejections so clients can tell them apart.
	errQuota = "ERR_QUOTA_EXCEEDED"
	errDisk  = "ERR_DISK_FULL"
	// errImportLimit: too many or too large import archives for the account.
	errImportLimit = "ERR_IMPORT_LIMIT"
)

type ownerKey struct{}

type service struct {
	// creating serializes upload creations per account, so the import allowance check and the creation
	// of the upload happen together.
	creating sync.Map // owner → *sync.Mutex
	app      core.App
	store    filestore.FileStore
	tus      http.Handler
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

	floor := takeout.SafetyFloor
	if id := strings.Trim(strings.TrimPrefix(e.Request.URL.Path, BasePath), "/"); id != "" {
		info, ok := s.infoOf(ctx, id, owner)
		if !ok {
			return e.NotFoundError("", nil)
		}
		if info.MetaData[metaPurpose] == purposeImport {
			floor = takeout.ImportFloor
		}
	}
	// Every chunk must leave the disk's floor free: a full disk would stop the database. Import archives
	// keep a larger margin than regular uploads (phone backups on a small SD card must keep working).
	if e.Request.Method == http.MethodPatch && !takeout.FitsOnDisk(s.app.DataDir(), max(e.Request.ContentLength, 0), false, floor) {
		e.Response.Header().Set("Tus-Resumable", "1.0.0")
		return e.String(http.StatusInsufficientStorage, errDisk+": not enough disk space on the server")
	}
	if e.Request.Method == http.MethodPost {
		m, _ := s.creating.LoadOrStore(owner, &sync.Mutex{})
		m.(*sync.Mutex).Lock()
		defer m.(*sync.Mutex).Unlock()
	}
	s.tus.ServeHTTP(e.Response, e.Request.WithContext(ctx))
	return nil
}

func (s *service) infoOf(ctx context.Context, id, owner string) (tusd.FileInfo, bool) {
	up, err := s.store.GetUpload(ctx, id)
	if err != nil {
		return tusd.FileInfo{}, false
	}
	info, err := up.GetInfo(ctx)
	return info, err == nil && info.MetaData[metaOwner] == owner
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
	if up.MetaData[metaPurpose] == purposeImport {
		return s.preCreateImport(owner, name, up.Size)
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

// preCreateImport accepts a Takeout archive: a .zip, within the account's import allowance (its quota
// left, or the server-wide cap without quota; 200 archives), that fits on the disk with its floor kept.
func (s *service) preCreateImport(owner, name string, size int64) (tusd.HTTPResponse, tusd.FileInfoChanges, error) {
	if !strings.EqualFold(filepath.Ext(name), ".zip") {
		return reject("ERR_INVALID_NAME", "import archives are .zip files", http.StatusBadRequest)
	}
	count, used := takeout.ImportUsage(s.app, owner)
	if count >= takeout.MaxUploads || used+size > takeout.UploadLimit(s.app, owner) {
		return reject(errImportLimit, "too many or too large import archives for this account", http.StatusRequestEntityTooLarge)
	}
	if !takeout.FitsOnDisk(s.app.DataDir(), size, true, takeout.ImportFloor) {
		return reject(errDisk, "not enough disk space on the server", http.StatusInsufficientStorage)
	}
	return tusd.HTTPResponse{}, tusd.FileInfoChanges{MetaData: tusd.MetaData{
		metaOwner: owner, metaFilename: name, metaPurpose: purposeImport,
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
	if meta[metaPurpose] == purposeImport {
		return s.finishImport(hook)
	}

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

// finishImport moves the archive out of the tus folder (whose stale files are swept daily) into the
// owner's import archives, named after the upload id (listed by GET /api/v1/imports/google/uploads).
func (s *service) finishImport(hook tusd.HookEvent) (tusd.HTTPResponse, error) {
	meta := hook.Upload.MetaData
	err := takeout.StoreUpload(s.app, meta[metaOwner], hook.Upload.ID, meta[metaFilename], hook.Upload.Storage[filestore.StorageKeyPath])
	s.discard(hook) // the .info file (and the data, if it could not be moved)
	if err != nil {
		s.app.Logger().Error("cannot keep an import archive", "upload", hook.Upload.ID, "error", err)
		return tusd.HTTPResponse{}, tusd.NewError("ERR_FINALIZE", "could not store the archive", http.StatusInternalServerError)
	}
	return tusd.HTTPResponse{}, nil
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
	node, err := drive.SaveNewFile(s.app, owner, parent, filename, func() (*filesystem.File, error) {
		return filesystem.NewFileFromPath(binPath)
	})
	if err != nil {
		return nil, fmt.Errorf("save node: %w", err)
	}
	return node, nil
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
