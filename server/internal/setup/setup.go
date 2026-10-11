// Package setup applies environment-driven settings on every boot and
// customizes the first-run (installer) experience.
package setup

import (
	"cmp"
	"fmt"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
)

const installerTokenTTL = 30 * time.Minute

// Register wires boot-time settings sync and the installer link.
func Register(app core.App, cfg config.Config) {
	app.OnBootstrap().BindFunc(func(e *core.BootstrapEvent) error {
		if err := e.Next(); err != nil {
			return err
		}
		return applySettings(e.App, cfg)
	})

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		if se.InstallerFunc != nil {
			se.InstallerFunc = func(app core.App, su *core.Record, listenURL string) error {
				return printInstallerLink(app, su, cmp.Or(cfg.PublicURL, listenURL))
			}
		}
		return se.Next()
	})
}

// printInstallerLink logs the one-time admin setup link. Unlike PocketBase's
// default, it never opens a browser: servers start headless (Docker, tests,
// CI) and the link must use the public URL, not the listen address.
func printInstallerLink(app core.App, su *core.Record, baseURL string) error {
	token, err := su.NewStaticAuthToken(installerTokenTTL)
	if err != nil {
		return err
	}
	link := strings.TrimRight(baseURL, "/") + "/_/#/pbinstall/" + token
	app.Logger().Info("first launch: open the setup link to create the administrator account", "url", link)
	fmt.Printf("\n(!) First launch: create the administrator account (link valid %s):\n%s\n\n", installerTokenTTL, link)
	return nil
}

func applySettings(app core.App, cfg config.Config) error {
	s := app.Settings()
	if s.Meta.AppName == "" || s.Meta.AppName == "Acme" {
		s.Meta.AppName = buildinfo.Name
	}
	if cfg.PublicURL != "" {
		s.Meta.AppURL = cfg.PublicURL
	}
	s.TrustedProxy.Headers = cfg.TrustedProxyHeaders
	s.TrustedProxy.UseLeftmostIP = false

	s.S3.Enabled = cfg.Storage == config.StorageS3
	if s.S3.Enabled {
		s.S3.Endpoint = cfg.S3.Endpoint
		s.S3.Region = cfg.S3.Region
		s.S3.Bucket = cfg.S3.Bucket
		s.S3.AccessKey = cfg.S3.AccessKey
		s.S3.Secret = cfg.S3.Secret
		s.S3.ForcePathStyle = cfg.S3.ForcePathStyle
	}
	if err := app.Save(s); err != nil {
		return fmt.Errorf("apply settings from environment: %w", err)
	}
	return nil
}
