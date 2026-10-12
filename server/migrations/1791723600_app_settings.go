package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

// Server-wide settings changed from the app (e.g. map tiles, ADR 0020). No API rules: only the server
// and superusers read or write them; dedicated routes expose what clients need.
func init() {
	m.Register(func(app core.App) error {
		c := core.NewBaseCollection("app_settings")
		c.Fields.Add(
			&core.TextField{Name: "key", Required: true, Max: 64, Pattern: `^[a-z0-9_.]+$`},
			&core.JSONField{Name: "value", MaxSize: 64 << 10},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		c.AddIndex("idx_app_settings_key", true, "key", "")
		return app.Save(c)
	}, func(app core.App) error {
		c, err := app.FindCollectionByNameOrId("app_settings")
		if err != nil {
			return err
		}
		return app.Delete(c)
	})
}
