package migrations

import (
	"slices"

	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

const totpRateLimitLabel = "/api/v1/me/totp"

// Authenticator-app enrolments. No API rules: only internal/totp touches it.
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		c := core.NewBaseCollection("totp")
		c.Fields.Add(
			&core.RelationField{Name: "user", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "secret_enc", Required: true, Hidden: true},
			&core.BoolField{Name: "enabled"},
			&core.JSONField{Name: "recovery", Hidden: true, MaxSize: 4096},
			&core.NumberField{Name: "last_step", Hidden: true, OnlyInt: true},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		c.AddIndex("idx_totp_user", true, "user", "")
		if err := app.Save(c); err != nil {
			return err
		}
		s := app.Settings()
		s.RateLimits.Rules = append([]core.RateLimitRule{
			{Label: totpRateLimitLabel, MaxRequests: 10, Duration: 60},
		}, s.RateLimits.Rules...)
		return app.Save(s)
	}, func(app core.App) error {
		s := app.Settings()
		s.RateLimits.Rules = slices.DeleteFunc(s.RateLimits.Rules, func(r core.RateLimitRule) bool {
			return r.Label == totpRateLimitLabel
		})
		if err := app.Save(s); err != nil {
			return err
		}
		c, err := app.FindCollectionByNameOrId("totp")
		if err != nil {
			return err
		}
		return app.Delete(c)
	})
}
