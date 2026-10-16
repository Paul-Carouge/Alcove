package migrations

import (
	"slices"

	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

const importsRateLimitLabel = "/api/v1/imports/" // trailing slash: a prefix rule

// importMediaFields are what a Google Takeout import knows about a photo (ADR 0030). The import_* values
// are kept apart from the EXIF-derived ones so the media worker can merge them every time it processes the
// file (EXIF wins when plausible) and never loses them on a retry.
var importMediaFields = []string{"description", "import_taken_at", "import_has_location", "import_lat", "import_lon"}

// Google Photos import from Takeout (ADR 0030): the "imports" jobs (read by their owner and the
// administrator who started them, written only by the server) and the imported metadata on "media".
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		media, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			return err
		}
		media.Fields.Add(
			&core.TextField{Name: "description", Max: 2000},
			&core.DateField{Name: "import_taken_at", Hidden: true},
			&core.BoolField{Name: "import_has_location", Hidden: true},
			&core.NumberField{Name: "import_lat", Hidden: true},
			&core.NumberField{Name: "import_lon", Hidden: true},
		)
		if err := app.Save(media); err != nil {
			return err
		}

		c := core.NewBaseCollection("imports")
		c.Fields.Add(
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.RelationField{Name: "created_by", CollectionId: users.Id, MaxSelect: 1, CascadeDelete: true},
			&core.SelectField{Name: "source", Required: true, MaxSelect: 1, Values: []string{"upload", "server"}},
			&core.JSONField{Name: "files", MaxSize: 64 << 10},
			&core.SelectField{Name: "status", Required: true, MaxSelect: 1,
				Values: []string{"queued", "scanning", "running", "done", "failed", "cancelled"}},
			&core.TextField{Name: "error", Max: 100},
			&core.NumberField{Name: "total", OnlyInt: true},
			&core.NumberField{Name: "processed", OnlyInt: true},
			&core.NumberField{Name: "imported", OnlyInt: true},
			&core.NumberField{Name: "duplicates", OnlyInt: true},
			&core.NumberField{Name: "skipped", OnlyInt: true},
			&core.NumberField{Name: "undated", OnlyInt: true},
			&core.NumberField{Name: "failed", OnlyInt: true},
			&core.NumberField{Name: "albums", OnlyInt: true},
			&core.JSONField{Name: "failures", MaxSize: 1 << 20},
			&core.JSONField{Name: "progress", Hidden: true, MaxSize: 1 << 20},
			&core.NumberField{Name: "attempts", Hidden: true, OnlyInt: true}, // restarts during the job
			&core.DateField{Name: "started_at"},
			&core.DateField{Name: "finished_at"},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		c.ListRule = types.Pointer(`owner = @request.auth.id || created_by = @request.auth.id`)
		c.ViewRule = c.ListRule
		c.AddIndex("idx_imports_owner", false, "owner", "")
		c.AddIndex("idx_imports_status", false, "status, created", "")
		if err := app.Save(c); err != nil {
			return err
		}

		s := app.Settings()
		s.RateLimits.Rules = append([]core.RateLimitRule{
			{Label: importsRateLimitLabel, MaxRequests: 30, Duration: 60},
		}, s.RateLimits.Rules...)
		return app.Save(s)
	}, func(app core.App) error {
		s := app.Settings()
		s.RateLimits.Rules = slices.DeleteFunc(s.RateLimits.Rules, func(r core.RateLimitRule) bool {
			return r.Label == importsRateLimitLabel
		})
		if err := app.Save(s); err != nil {
			return err
		}
		if c, err := app.FindCollectionByNameOrId("imports"); err == nil {
			if err := app.Delete(c); err != nil {
				return err
			}
		}
		media, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			return err
		}
		for _, name := range importMediaFields {
			media.Fields.RemoveByName(name)
		}
		return app.Save(media)
	})
}
