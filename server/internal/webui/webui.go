// Package webui serves the SvelteKit static build embedded in the binary.
// `make build` copies web/build into ./dist before compiling.
package webui

import (
	"embed"
	"io/fs"
	"net/http"
	"strings"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

//go:embed all:dist
var dist embed.FS

const placeholder = `<!doctype html><meta charset="utf-8"><title>Web UI not built</title>
<p>The web UI is not embedded in this build. Run <code>make build</code>, or use <code>make dev</code> for development.</p>`

// Register serves the SPA on every GET route not claimed by another handler.
func Register(app core.App) {
	sub, _ := fs.Sub(dist, "dist")
	_, err := fs.Stat(sub, "index.html")
	built := err == nil

	app.OnServe().Bind(&hook.Handler[*core.ServeEvent]{
		Func: func(se *core.ServeEvent) error {
			if built {
				static := apis.Static(sub, true)
				se.Router.GET("/{path...}", func(e *core.RequestEvent) error {
					// Unknown API routes must stay JSON 404s, not the SPA's index.html.
					if strings.HasPrefix(e.Request.URL.Path, "/api/") {
						return e.NotFoundError("", nil)
					}
					return static(e)
				})
			} else {
				se.Router.GET("/{$}", func(e *core.RequestEvent) error {
					return e.HTML(http.StatusOK, placeholder)
				})
			}
			return se.Next()
		},
		Priority: 999, // last, so API routes win
	})
}
