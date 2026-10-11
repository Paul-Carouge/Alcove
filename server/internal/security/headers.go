// Package security contains HTTP hardening shared by all routes.
package security

import (
	"strings"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/hook"
)

// contentSecurityPolicy applies to the embedded web UI. script-src is enforced
// by the per-page <meta> CSP that SvelteKit generates with script hashes.
const contentSecurityPolicy = "default-src 'self'; img-src 'self' data: blob:; media-src 'self' blob:; " +
	"style-src 'self' 'unsafe-inline'; connect-src 'self'; font-src 'self'; object-src 'none'; " +
	"base-uri 'self'; form-action 'self'; frame-ancestors 'none'"

// RegisterHeaders adds defensive headers to every response. HSTS is set by
// the TLS-terminating proxy (Caddy), not here.
func RegisterHeaders(app core.App) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.Bind(&hook.Handler[*core.RequestEvent]{
			Id: "alcoveSecurityHeaders",
			Func: func(e *core.RequestEvent) error {
				h := e.Response.Header()
				h.Set("X-Content-Type-Options", "nosniff")
				h.Set("Referrer-Policy", "strict-origin-when-cross-origin")
				h.Set("X-Frame-Options", "DENY")
				h.Set("Permissions-Policy", "camera=(), microphone=(), geolocation=(), interest-cohort=()")
				// The PocketBase admin UI (/_/) ships its own inline scripts.
				if !strings.HasPrefix(e.Request.URL.Path, "/api/") && !strings.HasPrefix(e.Request.URL.Path, "/_/") {
					h.Set("Content-Security-Policy", contentSecurityPolicy)
				}
				return e.Next()
			},
		})
		return se.Next()
	})
}
