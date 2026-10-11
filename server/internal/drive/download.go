package drive

import (
	"mime"
	"strings"

	"github.com/pocketbase/pocketbase/core"
)

// DownloadPath serves a file under its drive name (PocketBase's own file
// route uses the random storage name).
const DownloadPath = "/api/v1/nodes/{id}/download"

// inlineTypes may be displayed (?inline=1). Anything able to run script on
// the origin (HTML, SVG, XML, …) is never served inline.
var inlineTypes = map[string]bool{
	"image/jpeg": true, "image/png": true, "image/gif": true, "image/webp": true, "image/avif": true,
	"application/pdf": true, "text/plain": true,
	"video/mp4": true, "video/webm": true,
	"audio/mpeg": true, "audio/ogg": true, "audio/wav": true, "audio/flac": true, "audio/mp4": true, "audio/webm": true,
}

// inlineCSP locks down a displayed file. PDF viewers cannot run in a
// sandboxed document, so PDFs get the same policy without "sandbox".
func inlineCSP(mimeType string) string {
	const base = "default-src 'none'; img-src 'self' data:; media-src 'self'; style-src 'unsafe-inline'; frame-ancestors 'self'"
	if mimeType == "application/pdf" {
		return base
	}
	return base + "; sandbox"
}

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
	mimeType, _, _ := strings.Cut(node.GetString("mime"), ";")
	disposition := "attachment"
	h := e.Response.Header()
	if e.Request.URL.Query().Get("inline") == "1" && inlineTypes[mimeType] {
		disposition = "inline"
		h.Set("Content-Type", node.GetString("mime")) // sniffed from content at upload, not client-declared
		h.Set("Content-Security-Policy", inlineCSP(mimeType))
		h.Set("X-Frame-Options", "SAMEORIGIN")
	}
	// FormatMediaType emits an RFC 2231 filename* for non-ASCII names.
	h.Set("Content-Disposition", mime.FormatMediaType(disposition, map[string]string{"filename": name}))
	h.Set("Cache-Control", "private, max-age=300")
	key := node.BaseFilesPath() + "/" + node.GetString("blob")
	if err := fsys.Serve(e.Response, e.Request, key, name); err != nil {
		return e.NotFoundError("", err)
	}
	return nil
}
