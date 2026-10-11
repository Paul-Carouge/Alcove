package migrations

import (
	"slices"

	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

// Public share links. Created only through POST /api/v1/shares (the server
// generates the token and stores its SHA-256); owners list and delete their
// links through the collection API. Secrets are hidden fields.
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

		shares := core.NewBaseCollection("shares")
		shares.Fields.Add(
			&core.RelationField{Name: "node", CollectionId: nodes.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.RelationField{Name: "created_by", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "token_hash", Required: true, Hidden: true, Pattern: `^[a-f0-9]{64}$`},
			&core.TextField{Name: "access_secret", Required: true, Hidden: true, Min: 32},
			&core.TextField{Name: "password_hash", Hidden: true},
			&core.BoolField{Name: "has_password"},
			&core.DateField{Name: "expires_at"},
			&core.AutodateField{Name: "created", OnCreate: true},
		)
		const own = `created_by = @request.auth.id`
		shares.ListRule = types.Pointer(own)
		shares.ViewRule = types.Pointer(own)
		shares.DeleteRule = types.Pointer(own)
		shares.CreateRule = nil
		shares.UpdateRule = nil
		shares.AddIndex("idx_shares_token_hash", true, "token_hash", "")
		shares.AddIndex("idx_shares_node", false, "node", "")
		if err := app.Save(shares); err != nil {
			return err
		}

		// Public endpoints get their own, stricter limits (first matching prefix wins).
		s := app.Settings()
		s.RateLimits.Rules = append([]core.RateLimitRule{
			{Label: "POST /api/v1/public/", MaxRequests: 10, Duration: 60}, // password attempts
			{Label: "/api/v1/public/", MaxRequests: 120, Duration: 60},
		}, s.RateLimits.Rules...)
		return app.Save(s)
	}, func(app core.App) error {
		s := app.Settings()
		s.RateLimits.Rules = slices.DeleteFunc(s.RateLimits.Rules, func(r core.RateLimitRule) bool {
			return r.Label == "POST /api/v1/public/" || r.Label == "/api/v1/public/"
		})
		if err := app.Save(s); err != nil {
			return err
		}
		shares, err := app.FindCollectionByNameOrId("shares")
		if err != nil {
			return err
		}
		return app.Delete(shares)
	})
}
