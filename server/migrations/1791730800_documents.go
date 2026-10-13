package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

// Text of documents (ADR 0025): one record per PDF, text file or image whose text was read, filled by
// the documents worker (internal/docs). Users read their own; only the server writes. The full-text
// index is a separate FTS5 table, kept in sync by the worker and searched by GET /api/v1/search.
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
		c := core.NewBaseCollection("documents")
		c.Fields.Add(
			&core.RelationField{Name: "node", CollectionId: nodes.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.SelectField{Name: "kind", Required: true, MaxSelect: 1, Values: []string{"pdf", "text", "image"}},
			&core.SelectField{Name: "status", Required: true, MaxSelect: 1, Values: []string{"pending", "ready", "skipped", "failed"}},
			&core.SelectField{Name: "method", MaxSelect: 1, Values: []string{"text", "pdf", "ocr"}},
			&core.TextField{Name: "reason", Max: 32, Help: "why it was skipped, e.g. ocr-off, no-tools, photo"},
			&core.TextField{Name: "text", Max: 1 << 20},
			&core.NumberField{Name: "pages", OnlyInt: true},
			&core.TextField{Name: "error", Hidden: true, Max: 500},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		c.ListRule = types.Pointer("owner = @request.auth.id")
		c.ViewRule = types.Pointer("owner = @request.auth.id")
		c.AddIndex("idx_documents_node", true, "node", "")
		c.AddIndex("idx_documents_owner", false, "owner, kind, status", "")
		c.AddIndex("idx_documents_status", false, "status", "")
		if err := app.Save(c); err != nil {
			return err
		}
		// remove_diacritics: "facture" finds "FACTURÉ". Prefix queries ("fact*") need no extra index.
		_, err = app.DB().NewQuery(`CREATE VIRTUAL TABLE documents_fts USING fts5(
			doc UNINDEXED, owner UNINDEXED, name, body,
			tokenize = 'unicode61 remove_diacritics 2'
		)`).Execute()
		return err
	}, func(app core.App) error {
		if _, err := app.DB().NewQuery(`DROP TABLE IF EXISTS documents_fts`).Execute(); err != nil {
			return err
		}
		c, err := app.FindCollectionByNameOrId("documents")
		if err != nil {
			return err
		}
		return app.Delete(c)
	})
}
