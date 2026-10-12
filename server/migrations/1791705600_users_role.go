package migrations

import (
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

const usersUpdateRuleRole = "id = @request.auth.id && @request.body.quota_bytes:isset = false && @request.body.role:isset = false"

// Adds users.role ("user" or "admin"; empty means user). App accounts that
// share their email with an admin-console superuser become admins.
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.Fields.Add(&core.SelectField{Name: "role", MaxSelect: 1, Values: []string{"user", "admin"}})
		users.UpdateRule = types.Pointer(usersUpdateRuleRole)
		if err := app.Save(users); err != nil {
			return err
		}
		supers, err := app.FindAllRecords(core.CollectionNameSuperusers,
			dbx.Not(dbx.HashExp{"email": core.DefaultInstallerEmail}))
		if err != nil {
			return err
		}
		for _, su := range supers {
			if u, err := app.FindAuthRecordByEmail(users, su.Email()); err == nil {
				u.Set("role", "admin")
				if err := app.Save(u); err != nil {
					return err
				}
			}
		}
		return nil
	}, func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.Fields.RemoveByName("role")
		users.UpdateRule = types.Pointer(usersUpdateRuleQuota)
		return app.Save(users)
	})
}
