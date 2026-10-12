package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

// Duplicate detection (v0.13): a perceptual hash per photo (dHash of the thumbnail, 16 hex digits) and the
// groups a user marked as "not duplicates".
func init() {
	m.Register(func(app core.App) error {
		media, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			return err
		}
		media.Fields.Add(&core.TextField{Name: "phash", Max: 16, Pattern: `^([0-9a-f]{16})?$`})
		if err := app.Save(media); err != nil {
			return err
		}
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		c := core.NewBaseCollection("duplicate_dismissals")
		c.Fields.Add(
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.RelationField{Name: "items", CollectionId: media.Id, Required: true, MaxSelect: 1000},
			&core.AutodateField{Name: "created", OnCreate: true},
		)
		// Written through POST /api/v1/photos/duplicates/dismiss; owners may list and undo theirs.
		c.ListRule = types.Pointer("owner = @request.auth.id")
		c.ViewRule = c.ListRule
		c.DeleteRule = c.ListRule
		return app.Save(c)
	}, func(app core.App) error {
		c, err := app.FindCollectionByNameOrId("duplicate_dismissals")
		if err != nil {
			return err
		}
		if err := app.Delete(c); err != nil {
			return err
		}
		media, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			return err
		}
		media.Fields.RemoveByName("phash")
		return app.Save(media)
	})
}
