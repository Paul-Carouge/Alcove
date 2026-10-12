// Package app wires every Alcove module into a PocketBase app. main.go only
// parses configuration and starts the server, so the full wiring is testable.
package app

import (
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/health"
	"github.com/Paul-Carouge/Alcove/server/internal/secrets"
	"github.com/Paul-Carouge/Alcove/server/internal/security"
	"github.com/Paul-Carouge/Alcove/server/internal/setup"
	"github.com/Paul-Carouge/Alcove/server/internal/shares"
	"github.com/Paul-Carouge/Alcove/server/internal/totp"
	"github.com/Paul-Carouge/Alcove/server/internal/uploads"
	"github.com/Paul-Carouge/Alcove/server/internal/webui"
)

// Wire registers all hooks and routes.
func Wire(app core.App, cfg config.Config) {
	setup.Register(app, cfg)
	security.RegisterHeaders(app, webui.ScriptSrc())
	drive.Register(app)
	shares.Register(app)
	totp.Register(app, secrets.New(app, cfg.SecretKey))
	uploads.Register(app, len(cfg.TrustedProxyHeaders) > 0)
	// Optional modules from ALCOVE_MODULES (ocr, faces) are not implemented yet.
	health.Register(app, []string{drive.Module})
	webui.Register(app)
}
