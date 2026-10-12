package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

const (
	usersUpdateRuleBefore = "id = @request.auth.id"
	// Users may edit their profile, never their own quota.
	usersUpdateRuleQuota = "id = @request.auth.id && @request.body.quota_bytes:isset = false"
)

// Per-user storage quota in bytes (0 = unlimited), set by the administrator.
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.Fields.Add(&core.NumberField{
			Name:    "quota_bytes",
			Min:     types.Pointer(0.0),
			OnlyInt: true,
			Help:    "Storage quota in bytes, trash included. 0 = unlimited.",
		})
		users.UpdateRule = types.Pointer(usersUpdateRuleQuota)
		return app.Save(users)
	}, func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.Fields.RemoveByName("quota_bytes")
		users.UpdateRule = types.Pointer(usersUpdateRuleBefore)
		return app.Save(users)
	})
}
