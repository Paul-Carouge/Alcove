package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

// Fast "do I already have this file?" lookups for phone backups (POST /api/v1/backup/known).
func init() {
	m.Register(func(app core.App) error {
		nodes, err := app.FindCollectionByNameOrId("nodes")
		if err != nil {
			return err
		}
		nodes.AddIndex("idx_nodes_owner_sha256", false, "owner, sha256", "")
		return app.Save(nodes)
	}, func(app core.App) error {
		nodes, err := app.FindCollectionByNameOrId("nodes")
		if err != nil {
			return err
		}
		nodes.RemoveIndex("idx_nodes_owner_sha256")
		return app.Save(nodes)
	})
}
