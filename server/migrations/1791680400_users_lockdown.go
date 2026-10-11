package migrations

import (
	"strings"

	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

const (
	pbResetPath     = "/_/#/auth/confirm-password-reset/"
	alcoveResetPath = "/reset-password/"
)

// Locks down the default users collection for a private instance:
// - no public sign-up (accounts are created by an admin; invitations later),
// - password-reset emails link to the web app instead of the admin UI.
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		users.CreateRule = nil
		users.ResetPasswordTemplate.Body = strings.ReplaceAll(users.ResetPasswordTemplate.Body, pbResetPath, alcoveResetPath)
		return app.Save(users)
	}, func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		publicSignup := ""
		users.CreateRule = &publicSignup
		users.ResetPasswordTemplate.Body = strings.ReplaceAll(users.ResetPasswordTemplate.Body, alcoveResetPath, pbResetPath)
		return app.Save(users)
	})
}
