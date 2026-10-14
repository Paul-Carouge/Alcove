package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

// TagColors are the colours a tag can take; clients map them to design tokens.
var TagColors = []string{"gray", "red", "orange", "yellow", "green", "teal", "blue", "violet", "pink"}

// Tags: per-user labels ("Invoices", "Taxes") put on files and folders. A node keeps up to 20 tag ids;
// internal/drive checks that they belong to the node's owner.
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		tags := core.NewBaseCollection("tags")
		tags.Fields.Add(
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "name", Required: true, Min: 1, Max: 40, Pattern: `^[^\x00-\x1f\x7f]*\S[^\x00-\x1f\x7f]*$`},
			&core.SelectField{Name: "color", Required: true, MaxSelect: 1, Values: TagColors},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		const owned = `owner = @request.auth.id`
		tags.ListRule = types.Pointer(owned)
		tags.ViewRule = types.Pointer(owned)
		tags.CreateRule = types.Pointer(`@request.auth.collectionName = "users" && @request.body.owner = @request.auth.id`)
		tags.UpdateRule = types.Pointer(owned + ` && @request.body.owner:isset = false`)
		tags.DeleteRule = types.Pointer(owned)
		tags.AddIndex("idx_tags_owner_name", true, "owner, name COLLATE NOCASE", "")
		if err := app.Save(tags); err != nil {
			return err
		}

		nodes, err := app.FindCollectionByNameOrId("nodes")
		if err != nil {
			return err
		}
		nodes.Fields.Add(&core.RelationField{Name: "tags", CollectionId: tags.Id, MaxSelect: 20})
		return app.Save(nodes)
	}, func(app core.App) error {
		nodes, err := app.FindCollectionByNameOrId("nodes")
		if err != nil {
			return err
		}
		nodes.Fields.RemoveByName("tags")
		if err := app.Save(nodes); err != nil {
			return err
		}
		tags, err := app.FindCollectionByNameOrId("tags")
		if err != nil {
			return err
		}
		return app.Delete(tags)
	})
}
