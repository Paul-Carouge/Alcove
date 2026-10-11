package drive

import (
	"mime"

	"github.com/pocketbase/pocketbase/core"
)

// DownloadPath serves a file under its drive name (PocketBase's own file
// route uses the random storage name).
const DownloadPath = "/api/v1/nodes/{id}/download"

func registerDownload(app core.App) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.GET(DownloadPath, download)
		return se.Next()
	})
}

// download authenticates with a short-lived *file* token (?token=, from
// POST /api/files/token) so plain links work without exposing the auth token.
func download(e *core.RequestEvent) error {
	user, err := e.App.FindAuthRecordByToken(e.Request.URL.Query().Get("token"), core.TokenTypeFile)
	if err != nil || user.Collection().Name != "users" {
		return e.UnauthorizedError("A valid file token is required.", nil)
	}
	node, err := e.App.FindRecordById(Collection, e.Request.PathValue("id"))
	if err != nil || node.GetString("owner") != user.Id || node.GetString("kind") != KindFile || node.GetString("blob") == "" {
		return e.NotFoundError("", nil)
	}

	fsys, err := e.App.NewFilesystem()
	if err != nil {
		return err
	}
	defer func() { _ = fsys.Close() }()

	name := node.GetString("name")
	// Always an attachment: user files are never rendered on the app origin.
	// FormatMediaType emits an RFC 2231 filename* for non-ASCII names.
	e.Response.Header().Set("Content-Disposition", mime.FormatMediaType("attachment", map[string]string{"filename": name}))
	e.Response.Header().Set("Cache-Control", "private, no-store")
	key := node.BaseFilesPath() + "/" + node.GetString("blob")
	if err := fsys.Serve(e.Response, e.Request, key, name); err != nil {
		return e.NotFoundError("", err)
	}
	return nil
}
