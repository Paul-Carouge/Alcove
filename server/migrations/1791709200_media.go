package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

// Photos and videos (phase 2). One record per image/video node, filled by the
// media worker (internal/media). Users read their own records; only the
// server writes them (favorites go through PUT /api/v1/media/{id}/favorite).
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		nodes, err := app.FindCollectionByNameOrId("nodes")
		if err != nil {
			return err
		}
		c := core.NewBaseCollection("media")
		c.Fields.Add(
			&core.RelationField{Name: "node", CollectionId: nodes.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.SelectField{Name: "kind", Required: true, MaxSelect: 1, Values: []string{"image", "video"}},
			&core.SelectField{Name: "status", Required: true, MaxSelect: 1, Values: []string{"pending", "ready", "failed"}},
			&core.DateField{Name: "taken_at"},
			&core.NumberField{Name: "width", OnlyInt: true},
			&core.NumberField{Name: "height", OnlyInt: true},
			&core.NumberField{Name: "duration"},
			&core.TextField{Name: "camera_make", Max: 100},
			&core.TextField{Name: "camera_model", Max: 100},
			&core.TextField{Name: "lens", Max: 150},
			&core.TextField{Name: "exposure", Max: 100, Help: "e.g. 1/250 s · f/2.8 · ISO 100 · 35 mm"},
			&core.BoolField{Name: "has_location"},
			&core.NumberField{Name: "lat"},
			&core.NumberField{Name: "lon"},
			&core.BoolField{Name: "favorite"},
			&core.FileField{Name: "thumb", MaxSelect: 1, MaxSize: 5 << 20, Protected: true},    // server-generated JPEG
			&core.FileField{Name: "preview", MaxSelect: 1, MaxSize: 20 << 20, Protected: true}, // server-generated JPEG
			&core.TextField{Name: "error", Hidden: true, Max: 500},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		c.ListRule = types.Pointer("owner = @request.auth.id")
		c.ViewRule = types.Pointer("owner = @request.auth.id")
		c.AddIndex("idx_media_node", true, "node", "")
		c.AddIndex("idx_media_timeline", false, "owner, taken_at", "")
		c.AddIndex("idx_media_status", false, "status", "")
		if err := app.Save(c); err != nil {
			return err
		}
		// Height-only thumbnail for the justified photo grid (keeps the ratio).
		return setNodeThumbs(app, append(append([]string{}, nodeThumbs...), "0x360"))
	}, func(app core.App) error {
		if err := setNodeThumbs(app, nodeThumbs); err != nil {
			return err
		}
		c, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			return err
		}
		return app.Delete(c)
	})
}
