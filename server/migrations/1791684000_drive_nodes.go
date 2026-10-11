package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

// Creates the drive tree: one record per file or folder.
//
// Access rules (everything is owner-only; sharing comes with the shares collection):
//   - size, mime and sha256 are computed by the server (internal/drive), never sent by clients;
//   - a node can only be placed in a folder of the same owner;
//   - owner and kind are immutable.
//
// Cycle prevention (moving a folder into its own subtree) is enforced by a hook.
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}

		nodes := core.NewBaseCollection("nodes")
		nodes.Fields.Add(
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			// Max 255 chars, no "/" or control characters, not "." or "..".
			&core.TextField{Name: "name", Required: true, Max: 255, Pattern: `^(?:[^/\x00-\x1f\x7f]*[^/\x00-\x1f\x7f.][^/\x00-\x1f\x7f]*)$`},
			&core.SelectField{Name: "kind", Required: true, MaxSelect: 1, Values: []string{"file", "folder"}},
			&core.FileField{Name: "blob", MaxSelect: 1, MaxSize: 64 << 30, Protected: true},
			&core.NumberField{Name: "size", Min: types.Pointer(0.0), OnlyInt: true},
			&core.TextField{Name: "mime", Max: 255},
			&core.TextField{Name: "sha256", Pattern: `^[a-f0-9]{64}$`},
			&core.DateField{Name: "trashed_at"},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		if err := app.Save(nodes); err != nil {
			return err
		}

		// Self-relation needs the collection id, so it is added after the first save.
		nodes.Fields.Add(&core.RelationField{Name: "parent", CollectionId: nodes.Id, MaxSelect: 1, CascadeDelete: true})

		const owned = `owner = @request.auth.id`
		const noComputed = `@request.body.size:isset = false && @request.body.mime:isset = false && @request.body.sha256:isset = false`
		const parentOk = `(@request.body.parent = "" || (@request.body.parent.owner = @request.auth.id && @request.body.parent.kind = "folder"))`
		nodes.ListRule = types.Pointer(owned)
		nodes.ViewRule = types.Pointer(owned)
		nodes.CreateRule = types.Pointer(`@request.auth.collectionName = "users" && @request.body.owner = @request.auth.id && ` + parentOk + ` && ` + noComputed)
		nodes.UpdateRule = types.Pointer(owned + ` && @request.body.owner:isset = false && @request.body.kind:isset = false && ` +
			`(@request.body.parent:isset = false || ` + parentOk + `) && ` + noComputed)
		nodes.DeleteRule = types.Pointer(owned)

		// Names are unique per folder among non-trashed nodes, case-insensitively
		// (so the tree can be synced to case-insensitive filesystems).
		nodes.AddIndex("idx_nodes_unique_name", true, "owner, parent, name COLLATE NOCASE", "trashed_at = ''")
		nodes.AddIndex("idx_nodes_parent", false, "owner, parent", "")
		nodes.AddIndex("idx_nodes_trashed", false, "owner, trashed_at", "")
		nodes.AddIndex("idx_nodes_sha256", false, "sha256", "sha256 != ''")
		return app.Save(nodes)
	}, func(app core.App) error {
		nodes, err := app.FindCollectionByNameOrId("nodes")
		if err != nil {
			return err
		}
		return app.Delete(nodes)
	})
}
