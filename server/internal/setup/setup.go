// Package setup applies environment-driven settings on every boot and
// customizes the first-run (installer) experience.
package setup

import (
	"fmt"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
)

// Register wires boot-time settings sync and the installer link.
func Register(app core.App, cfg config.Config) {
	app.OnBootstrap().BindFunc(func(e *core.BootstrapEvent) error {
		if err := e.Next(); err != nil {
			return err
		}
		return applySettings(e.App, cfg)
	})

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		// In Docker the listen address (0.0.0.0:8090) is not what the admin
		// opens in a browser: print the installer link with the public URL.
		if cfg.PublicURL != "" && se.InstallerFunc != nil {
			se.InstallerFunc = func(app core.App, su *core.Record, _ string) error {
				return apis.DefaultInstallerFunc(app, su, cfg.PublicURL)
			}
		}
		return se.Next()
	})
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
