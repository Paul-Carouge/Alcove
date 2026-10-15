// Package app wires every Alcove module into a PocketBase app. main.go only
// parses configuration and starts the server, so the full wiring is testable.
package app

import (
	"os"
	"path/filepath"

	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/accounts"
	"github.com/Paul-Carouge/Alcove/server/internal/albums"
	"github.com/Paul-Carouge/Alcove/server/internal/appdist"
	"github.com/Paul-Carouge/Alcove/server/internal/archive"
	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/docs"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/duplicates"
	"github.com/Paul-Carouge/Alcove/server/internal/health"
	"github.com/Paul-Carouge/Alcove/server/internal/maps"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/notes"
	"github.com/Paul-Carouge/Alcove/server/internal/secrets"
	"github.com/Paul-Carouge/Alcove/server/internal/security"
	"github.com/Paul-Carouge/Alcove/server/internal/service"
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
	releases, err := updater.New(updateOpts.APIBase, buildinfo.Repo, buildinfo.ReleasePublicKey)
	if err == nil {
		appdist.Register(app, releases, buildinfo.Version)
	}
	documents := docs.Register(app, docs.Options{
		Releases: releases,
		Version:  buildinfo.Version,
		Binary:   executable(),
		Docker:   updateOpts.Mode == "docker",
		CanInstall: func() bool {
			return updateOpts.Mode == "native" && os.Getenv(service.EnvInstalled) != ""
		},
	})
	uploads.Register(app, len(cfg.TrustedProxyHeaders) > 0)
	archive.Register(app)
	notes.Register(app)
	// Face recognition (ALCOVE_MODULES=faces) is not implemented yet.
	health.Register(app, []string{drive.Module, media.Module, notes.Module}, documents.Modules)
	webui.Register(app)
}

// executable is the running binary with symlinks resolved, or "" when unknown.
func executable() string {
	exe, err := os.Executable()
	if err != nil {
		return ""
	}
	if exe, err = filepath.EvalSymlinks(exe); err != nil {
		return ""
	}
	return exe
}
