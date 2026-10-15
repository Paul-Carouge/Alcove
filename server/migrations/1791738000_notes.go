package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

// Notes (ADR 0027): Markdown notes stored in the database, one record per note, owner-only. Tags reuse
// the `tags` collection (internal/notes checks they belong to the note's owner); trashed notes keep a
// trashed_at date and are deleted for good after the drive's trash retention.
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		tags, err := app.FindCollectionByNameOrId("tags")
		if err != nil {
			return err
		}
		c := core.NewBaseCollection("notes")
		c.Fields.Add(
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "title", Max: 200},
			&core.TextField{Name: "body", Max: 1 << 20},
			&core.BoolField{Name: "pinned"},
			&core.RelationField{Name: "tags", CollectionId: tags.Id, MaxSelect: 20},
			&core.DateField{Name: "trashed_at"},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		const owned = `owner = @request.auth.id`
		c.ListRule = types.Pointer(owned)
		c.ViewRule = types.Pointer(owned)
		c.CreateRule = types.Pointer(`@request.auth.collectionName = "users" && @request.body.owner = @request.auth.id`)
		c.UpdateRule = types.Pointer(owned + ` && @request.body.owner:isset = false`)
		c.DeleteRule = types.Pointer(owned)
		c.AddIndex("idx_notes_owner", false, "owner, trashed_at, pinned, updated", "")
		return app.Save(c)
	}, func(app core.App) error {
		c, err := app.FindCollectionByNameOrId("notes")
		if err != nil {
			return err
		}
		return app.Delete(c)
	})
}
