package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

// Public links can point to an album instead of a node (ADR 0019). Exactly one of node and album is
// set, enforced by POST /api/v1/shares, the only way to create a link.
func init() {
	m.Register(func(app core.App) error {
		shares, err := app.FindCollectionByNameOrId("shares")
		if err != nil {
			return err
		}
		albums, err := app.FindCollectionByNameOrId("albums")
		if err != nil {
			return err
		}
		if f, ok := shares.Fields.GetByName("node").(*core.RelationField); ok {
			f.Required = false
		}
		shares.Fields.Add(&core.RelationField{Name: "album", CollectionId: albums.Id, MaxSelect: 1, CascadeDelete: true})
		return app.Save(shares)
	}, func(app core.App) error {
		if _, err := app.DB().NewQuery("DELETE FROM shares WHERE node = ''").Execute(); err != nil {
			return err
		}
		shares, err := app.FindCollectionByNameOrId("shares")
		if err != nil {
			return err
		}
		shares.Fields.RemoveByName("album")
		if f, ok := shares.Fields.GetByName("node").(*core.RelationField); ok {
			f.Required = true
		}
		return app.Save(shares)
	})
}
