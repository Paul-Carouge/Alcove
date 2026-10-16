package takeout

import (
	"net/http"
	"os"
	"path/filepath"
	"slices"
	"strings"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

const maxFiles = 200

func isAdmin(e *core.RequestEvent) bool { return e.Auth != nil && e.Auth.GetString("role") == "admin" }

func (r *Runner) routes(se *core.ServeEvent) {
	g := se.Router.Group("/api/v1/imports").Bind(apis.RequireAuth("users"))
	g.POST("/google", r.create)
	g.GET("/google/server-files", r.serverFiles)
	g.GET("/google/uploads", listUploadsRoute)
	g.DELETE("/google/uploads/{id}", r.deleteUploadRoute)
	g.POST("/{id}/cancel", r.cancelRoute)
}

// listUploadsRoute lists the caller's finished import archives no unfinished job uses.
func listUploadsRoute(e *core.RequestEvent) error {
	stored, err := ListUploads(e.App, e.Auth.Id)
	if err != nil {
		return err
	}
	used, err := usedUploads(e.App)
	if err != nil {
		return err
	}
	items := []StoredUpload{}
	for _, u := range stored {
		if !used[e.Auth.Id+"/"+u.ID] {
			items = append(items, u)
		}
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, map[string]any{"items": items})
}

func (r *Runner) deleteUploadRoute(e *core.RequestEvent) error {
	id := e.Request.PathValue("id")
	r.mu.Lock() // a job created meanwhile must not lose its archive
	defer r.mu.Unlock()
	used, err := usedUploads(e.App)
	if err != nil {
		return err
	}
	if used[e.Auth.Id+"/"+id] {
		return e.Error(http.StatusConflict, "An unfinished import uses this archive.", nil)
	}
	if err := DeleteUpload(e.App, e.Auth.Id, id); err != nil {
		return e.NotFoundError("", nil)
	}
	return e.NoContent(http.StatusNoContent)
}

// validServerName: one entry of the import folder, never a path.
func validServerName(name string) bool {
	return name != "" && len(name) <= 255 && !strings.ContainsAny(name, "/\\\x00") && !strings.HasPrefix(name, ".")
}

func (r *Runner) create(e *core.RequestEvent) error {
	var body struct {
		Uploads     []string `json:"uploads"`
		ServerFiles []string `json:"serverFiles"`
		User        string   `json:"user"`
	}
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("Invalid body.", nil)
	}
	if (len(body.Uploads) == 0) == (len(body.ServerFiles) == 0) || len(body.Uploads) > maxFiles || len(body.ServerFiles) > maxFiles {
		return e.BadRequestError("Give either uploads or serverFiles (at most 200).", nil)
	}
	owner, source, files := e.Auth.Id, "upload", slices.Compact(slices.Sorted(slices.Values(body.Uploads)))
	if len(body.ServerFiles) > 0 || body.User != "" {
		if !isAdmin(e) {
			return e.ForbiddenError("Administrators only.", nil)
		}
		if len(body.ServerFiles) == 0 {
			return e.BadRequestError("user can only be given with serverFiles.", nil)
		}
	}
	if len(body.ServerFiles) > 0 {
		source, files = "server", slices.Compact(slices.Sorted(slices.Values(body.ServerFiles)))
		if body.User != "" {
			u, err := e.App.FindRecordById("users", body.User)
			if err != nil {
				return e.BadRequestError("Unknown user.", nil)
			}
			owner = u.Id
		}
		root, err := os.OpenRoot(filepath.Join(e.App.DataDir(), ServerDir))
		if err != nil {
			return e.BadRequestError("Unknown server file.", nil)
		}
		defer func() { _ = root.Close() }()
		for _, f := range files {
			info, err := root.Lstat(f)
			ok := err == nil && validServerName(f) && (info.IsDir() || info.Mode().IsRegular() && isZip(f))
			if !ok {
				return e.BadRequestError("Unknown server file.", map[string]any{"name": f})
			}
		}
	} else {
		root, err := os.OpenRoot(filepath.Join(e.App.DataDir(), UploadDir, owner))
		if err != nil {
			return e.BadRequestError("Unknown upload.", nil)
		}
		defer func() { _ = root.Close() }()
		for _, f := range files {
			if info, err := root.Lstat(f + ".zip"); !uploadID.MatchString(f) || err != nil || !info.Mode().IsRegular() {
				return e.BadRequestError("Unknown upload.", nil)
			}
		}
	}

	r.mu.Lock() // one unfinished import per account, even with concurrent requests
	defer r.mu.Unlock()
	n, err := e.App.CountRecords(Collection, dbx.HashExp{"owner": owner}, dbx.In("status", StatusQueued, StatusScanning, StatusRunning))
	if err != nil {
		return err
	}
	if n > 0 {
		return e.Error(http.StatusConflict, "This account already has an unfinished import.", nil)
	}
	col, err := e.App.FindCollectionByNameOrId(Collection)
	if err != nil {
		return err
	}
	job := core.NewRecord(col)
	job.Set("owner", owner)
	job.Set("created_by", e.Auth.Id)
	job.Set("source", source)
	job.Set("files", files)
	job.Set("status", StatusQueued)
	job.Set("failures", []any{})
	if err := e.App.Save(job); err != nil {
		return err
	}
	r.Wake()
	return e.JSON(http.StatusCreated, job)
}

func isZip(name string) bool { return strings.EqualFold(filepath.Ext(name), ".zip") }

func (r *Runner) serverFiles(e *core.RequestEvent) error {
	if !isAdmin(e) {
		return e.ForbiddenError("Administrators only.", nil)
	}
	dir := filepath.Join(e.App.DataDir(), ServerDir)
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return err
	}
	abs, _ := filepath.Abs(dir)
	entries, err := os.ReadDir(dir)
	if err != nil {
		return err
	}
	items := []map[string]any{}
	for _, d := range entries {
		if !validServerName(d.Name()) {
			continue
		}
		switch {
		case d.IsDir():
			items = append(items, map[string]any{"name": d.Name(), "kind": "folder", "size": 0})
		case d.Type().IsRegular() && isZip(d.Name()): // symbolic links are ignored
			if info, err := d.Info(); err == nil {
				items = append(items, map[string]any{"name": d.Name(), "kind": "zip", "size": info.Size()})
			}
		}
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, map[string]any{"dir": abs, "items": items})
}

func (r *Runner) cancelRoute(e *core.RequestEvent) error {
	job, err := e.App.FindRecordById(Collection, e.Request.PathValue("id"))
	if err != nil || (job.GetString("owner") != e.Auth.Id && job.GetString("created_by") != e.Auth.Id && !isAdmin(e)) {
		return e.NotFoundError("", nil)
	}
	ok, err := r.Cancel(job.Id)
	if err != nil {
		return err
	}
	if !ok {
		return e.Error(http.StatusConflict, "The import has already finished.", nil)
	}
	return e.NoContent(http.StatusNoContent)
}
