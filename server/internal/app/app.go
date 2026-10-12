// Package app wires every Alcove module into a PocketBase app. main.go only
// parses configuration and starts the server, so the full wiring is testable.
package app

import (
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/accounts"
	"github.com/Paul-Carouge/Alcove/server/internal/albums"
	"github.com/Paul-Carouge/Alcove/server/internal/appdist"
	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/duplicates"
	"github.com/Paul-Carouge/Alcove/server/internal/health"
	"github.com/Paul-Carouge/Alcove/server/internal/maps"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/secrets"
	"github.com/Paul-Carouge/Alcove/server/internal/security"
	"github.com/Paul-Carouge/Alcove/server/internal/setup"
	"github.com/Paul-Carouge/Alcove/server/internal/shares"
	"github.com/Paul-Carouge/Alcove/server/internal/totp"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
	"github.com/Paul-Carouge/Alcove/server/internal/updates"
	"github.com/Paul-Carouge/Alcove/server/internal/uploads"
	"github.com/Paul-Carouge/Alcove/server/internal/webui"
	"github.com/Paul-Carouge/Alcove/server/internal/wizard"
)

// Wire registers all hooks and routes.
func Wire(app core.App, cfg config.Config) {
	setup.Register(app, cfg)
	wizard.Register(app, cfg)
	mapSettings := maps.Register(app)
	security.RegisterHeaders(app, webui.ScriptSrc(), mapSettings.ExtraImgSrc)
	drive.Register(app)
	media.Register(app)
	albums.Register(app)
	duplicates.Register(app)
	accounts.Register(app)
	shares.Register(app)
	totp.Register(app, secrets.New(app, cfg.SecretKey))
	updateOpts := updates.FromConfig(cfg)
	updates.Register(app, updateOpts)
	if releases, err := updater.New(updateOpts.APIBase, buildinfo.Repo, buildinfo.ReleasePublicKey); err == nil {
		appdist.Register(app, releases, buildinfo.Version)
	}
	uploads.Register(app, len(cfg.TrustedProxyHeaders) > 0)
	// Optional modules from ALCOVE_MODULES (ocr, faces) are not implemented yet.
	health.Register(app, []string{drive.Module, media.Module})
	webui.Register(app)
}
