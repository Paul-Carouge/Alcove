// Package setup applies environment-driven settings on every boot and
// customizes the first-run (installer) experience.
package setup

import (
	"fmt"

	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
)

// Register syncs environment-driven settings on every boot. (The first-run
// link is handled by internal/wizard.)
func Register(app core.App, cfg config.Config) {
	app.OnBootstrap().BindFunc(func(e *core.BootstrapEvent) error {
		if err := e.Next(); err != nil {
			return err
		}
		return applySettings(e.App, cfg)
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
