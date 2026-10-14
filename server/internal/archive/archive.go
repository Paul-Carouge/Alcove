// Package archive downloads several files at once as a ZIP: a selection of files and folders
// (folders with their content) or an album. The request is checked and resolved when the ticket is
// made (POST), then a plain link streams the archive (GET), so browsers download it like any file.
package archive

import (
	"archive/zip"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"mime"
	"net/http"
	"path"
	"strings"
	"sync"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/albums"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

const (
	// ticketTTL: how long the download link works.
	ticketTTL = 10 * time.Minute
	maxIDs    = 2000
	maxFiles  = 20000
	maxDepth  = 64
	maxTicket = 256 // live tickets per server
)

type entry struct {
	path string // inside the archive; ends with "/" for an empty folder
	node *core.Record
}

type ticket struct {
	user    string
	name    string
	entries []entry
	expires time.Time
}

type store struct {
	mu      sync.Mutex
	tickets map[string]*ticket
}

func (s *store) put(t *ticket) (string, error) {
	b := make([]byte, 24)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	id := base64.RawURLEncoding.EncodeToString(b)
	s.mu.Lock()
	defer s.mu.Unlock()
	now := time.Now()
	for k, v := range s.tickets {
		if now.After(v.expires) {
			delete(s.tickets, k)
		}
	}
	if len(s.tickets) >= maxTicket {
		return "", errBusy
	}
	s.tickets[id] = t
	return id, nil
}

func (s *store) get(id string) *ticket {
	s.mu.Lock()
	defer s.mu.Unlock()
	t := s.tickets[id]
	if t == nil || time.Now().After(t.expires) {
		return nil
	}
	return t
}

var errBusy = errors.New("too many downloads being prepared")

// Register mounts POST /api/v1/zip and GET /api/v1/zip/{ticket}.
func Register(app core.App) {
	s := &store{tickets: map[string]*ticket{}}
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.POST("/api/v1/zip", s.create).Bind(apis.RequireAuth("users"))
		se.Router.GET("/api/v1/zip/{ticket}", s.download)
		return se.Next()
	})
}

type request struct {
	Nodes []string `json:"nodes"`
	Album string   `json:"album"`
	Name  string   `json:"name"`
}

func (s *store) create(e *core.RequestEvent) error {
	var req request
	if err := e.BindBody(&req); err != nil {
		return e.BadRequestError("Invalid body.", nil)
	}
	if (len(req.Nodes) == 0) == (req.Album == "") || len(req.Nodes) > maxIDs {
		return e.BadRequestError("Give either nodes (1 to 2000 ids) or an album.", nil)
	}
	var (
		entries []entry
		name    = strings.TrimSpace(req.Name)
		err     error
	)
	if req.Album != "" {
		album, ferr := e.App.FindRecordById(albums.Collection, req.Album)
		if ferr != nil || albums.RoleOf(album, e.Auth.Id) == "" {
			return e.NotFoundError("", nil)
		}
		if name == "" {
			name = album.GetString("name")
		}
		entries, err = albumEntries(e.App, album.Id)
	} else {
		entries, err = nodeEntries(e.App, e.Auth.Id, req.Nodes)
	}
	if err != nil {
		if errors.Is(err, errTooMany) {
			return e.BadRequestError("Too many files for one archive (20,000 at most).", nil)
		}
		if errors.Is(err, errNotFound) {
			return e.NotFoundError("", nil)
		}
		return err
	}
	if len(entries) == 0 {
		return e.BadRequestError("Nothing to download.", nil)
	}
	if name == "" {
		name = "Alcove"
		if len(req.Nodes) == 1 && len(entries) > 0 {
			name = strings.SplitN(entries[0].path, "/", 2)[0]
		}
	}
	id, err := s.put(&ticket{user: e.Auth.Id, name: safeName(name), entries: entries, expires: time.Now().Add(ticketTTL)})
	if errors.Is(err, errBusy) {
		return e.TooManyRequestsError("Too many downloads are being prepared; try again in a minute.", nil)
	}
	if err != nil {
		return err
	}
	return e.JSON(http.StatusOK, map[string]any{
		"url":       "/api/v1/zip/" + id,
		"files":     len(entries),
		"expiresAt": time.Now().Add(ticketTTL).UTC().Format(time.RFC3339),
	})
}

var (
	errTooMany  = errors.New("too many files")
	errNotFound = errors.New("not found")
)

// names hands out unique names per folder of the archive, like the drive does ("a (2).txt").
type names map[string]bool

func (n names) take(dir, name string) string {
	ext := path.Ext(name)
	base := strings.TrimSuffix(name, ext)
	if base == "" {
		base, ext = name, ""
	}
	candidate := name
	for i := 2; n[strings.ToLower(dir+candidate)]; i++ {
		candidate = fmt.Sprintf("%s (%d)%s", base, i, ext)
	}
	n[strings.ToLower(dir+candidate)] = true
	return candidate
}

func nodeEntries(app core.App, owner string, ids []string) ([]entry, error) {
	used := names{}
	var out []entry
	seen := map[string]bool{}
	var walk func(n *core.Record, dir string, depth int) error
	walk = func(n *core.Record, dir string, depth int) error {
		if seen[n.Id] || depth > maxDepth {
			return nil
		}
		seen[n.Id] = true
		name := used.take(dir, n.GetString("name"))
		if n.GetString("kind") == drive.KindFile {
			if n.GetString("blob") == "" {
				return nil
			}
			out = append(out, entry{path: dir + name, node: n})
			if len(out) > maxFiles {
				return errTooMany
			}
			return nil
		}
		var children []*core.Record
		if err := app.RecordQuery(drive.Collection).
			AndWhere(dbx.HashExp{"owner": owner, "parent": n.Id, "trashed_at": ""}).
			OrderBy("kind DESC", "name ASC").All(&children); err != nil {
			return err
		}
		if len(children) == 0 {
			out = append(out, entry{path: dir + name + "/"})
			return nil
		}
		for _, c := range children {
			if err := walk(c, dir+name+"/", depth+1); err != nil {
				return err
			}
		}
		return nil
	}
	for _, id := range ids {
		n, err := app.FindRecordById(drive.Collection, id)
		if err != nil || n.GetString("owner") != owner || n.GetString("trashed_at") != "" {
			return nil, errNotFound
		}
		if err := walk(n, "", 0); err != nil {
			return nil, err
		}
	}
	return out, nil
}

func albumEntries(app core.App, album string) ([]entry, error) {
	ids, err := albums.NodeIDs(app, album)
	if err != nil {
		return nil, err
	}
	if len(ids) > maxFiles {
		return nil, errTooMany
	}
	nodes, err := app.FindRecordsByIds(drive.Collection, ids)
	if err != nil {
		return nil, err
	}
	byID := make(map[string]*core.Record, len(nodes))
	for _, n := range nodes {
		byID[n.Id] = n
	}
	used := names{}
	out := make([]entry, 0, len(ids))
	for _, id := range ids {
		if n := byID[id]; n != nil && n.GetString("blob") != "" {
			out = append(out, entry{path: used.take("", n.GetString("name")), node: n})
		}
	}
	return out, nil
}

// safeName makes a download file name: no path separators or control characters, 100 runes at most.
func safeName(s string) string {
	s = strings.Map(func(r rune) rune {
		if r < 0x20 || r == 0x7f || r == '/' || r == '\\' {
			return '_'
		}
		return r
	}, strings.TrimSpace(s))
	if r := []rune(s); len(r) > 100 {
		s = string(r[:100])
	}
	if strings.Trim(s, ". ") == "" {
		return "Alcove"
	}
	return s
}

// compressible types are deflated; photos, videos and archives are stored as they are.
func compressible(mimeType string) bool {
	m, _, _ := strings.Cut(mimeType, ";")
	return strings.HasPrefix(m, "text/") || m == "application/json" || m == "application/xml" ||
		m == "image/svg+xml" || m == "application/x-yaml"
}

func (s *store) download(e *core.RequestEvent) error {
	t := s.get(e.Request.PathValue("ticket"))
	if t == nil {
		return e.NotFoundError("This download link has expired.", nil)
	}
	fsys, err := e.App.NewFilesystem()
	if err != nil {
		return err
	}
	defer func() { _ = fsys.Close() }()

	h := e.Response.Header()
	h.Set("Content-Type", "application/zip")
	h.Set("Content-Disposition", mime.FormatMediaType("attachment", map[string]string{"filename": t.name + ".zip"}))
	h.Set("Cache-Control", "private, no-store")
	e.Response.WriteHeader(http.StatusOK)

	zw := zip.NewWriter(e.Response)
	for _, en := range t.entries {
		if en.node == nil {
			if _, err := zw.Create(en.path); err != nil {
				return nil
			}
			continue
		}
		method := zip.Store
		if compressible(en.node.GetString("mime")) {
			method = zip.Deflate
		}
		w, err := zw.CreateHeader(&zip.FileHeader{
			Name:     en.path,
			Method:   method,
			Modified: en.node.GetDateTime("updated").Time(),
		})
		if err != nil {
			return nil // the client went away
		}
		r, err := fsys.GetReader(en.node.BaseFilesPath() + "/" + en.node.GetString("blob"))
		if err != nil {
			e.App.Logger().Warn("zip: file missing", "node", en.node.Id, "error", err)
			continue
		}
		_, err = io.Copy(w, r)
		_ = r.Close()
		if err != nil {
			return nil
		}
	}
	_ = zw.Close()
	return nil
}
