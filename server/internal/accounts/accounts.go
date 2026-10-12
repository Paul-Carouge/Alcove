// Package accounts lets administrators manage the accounts of the server from the app (no need for the
// PocketBase console): list with storage use, create, change name/quota/role/password, delete.
package accounts

import (
	"net/http"
	"net/mail"
	"strings"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/totp"
)

const (
	users       = "users"
	roleAdmin   = "admin"
	minPassword = 10
)

// Register mounts the routes (administrators only).
func Register(app core.App) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		g := se.Router.Group("/api/v1/admin/users").Bind(apis.RequireAuth(users)).BindFunc(requireAdmin)
		g.GET("", list)
		g.POST("", create)
		g.PATCH("/{id}", update)
		g.DELETE("/{id}", remove)
		return se.Next()
	})
}

func requireAdmin(e *core.RequestEvent) error {
	if e.Auth == nil || e.Auth.GetString("role") != roleAdmin {
		return e.ForbiddenError("Administrators only.", nil)
	}
	return e.Next()
}

func view(app core.App, u *core.Record) map[string]any {
	usage, _ := drive.UsageOf(app, u.Id, "")
	return map[string]any{
		"id": u.Id, "email": u.Email(), "name": u.GetString("name"),
		"admin":      u.GetString("role") == roleAdmin,
		"quotaBytes": u.GetInt("quota_bytes"),
		"usedBytes":  usage.Used + usage.Trash,
		"twoFactor":  totp.Enabled(app, u.Id),
		"created":    u.GetString("created"),
	}
}

func list(e *core.RequestEvent) error {
	recs, err := e.App.FindRecordsByFilter(users, "", "email", 0, 0)
	if err != nil {
		return err
	}
	out := make([]map[string]any, len(recs))
	for i, u := range recs {
		out[i] = view(e.App, u)
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, map[string]any{"items": out})
}

type changes struct {
	Email      string  `json:"email"`
	Name       *string `json:"name"`
	Password   string  `json:"password"`
	QuotaBytes *int64  `json:"quotaBytes"`
	Admin      *bool   `json:"admin"`
}

func (c changes) validate(creating bool) string {
	if creating {
		if a, err := mail.ParseAddress(c.Email); err != nil || a.Address != c.Email || len(c.Email) > 254 {
			return "A valid email is required."
		}
		if c.Password == "" {
			return "A password is required."
		}
	}
	if c.Password != "" && (len(c.Password) < minPassword || len(c.Password) > 256) {
		return "The password must be at least 10 characters long."
	}
	if c.Name != nil && len(*c.Name) > 100 {
		return "The name is too long."
	}
	if c.QuotaBytes != nil && *c.QuotaBytes < 0 {
		return "The quota cannot be negative."
	}
	return ""
}

func (c changes) apply(u *core.Record) {
	if c.Name != nil {
		u.Set("name", strings.TrimSpace(*c.Name))
	}
	if c.QuotaBytes != nil {
		u.Set("quota_bytes", *c.QuotaBytes)
	}
	if c.Admin != nil {
		role := "user"
		if *c.Admin {
			role = roleAdmin
		}
		u.Set("role", role)
	}
	if c.Password != "" {
		u.SetPassword(c.Password) // also changes the token key: signed out everywhere
	}
}

func create(e *core.RequestEvent) error {
	var c changes
	if err := e.BindBody(&c); err != nil {
		return e.BadRequestError("Invalid body.", err)
	}
	c.Email = strings.TrimSpace(c.Email)
	if msg := c.validate(true); msg != "" {
		return e.BadRequestError(msg, nil)
	}
	if n, _ := e.App.CountRecords(users, dbx.NewExp("email = {:e} COLLATE NOCASE", dbx.Params{"e": c.Email})); n > 0 {
		return e.BadRequestError("This email is already used by another account.", nil)
	}
	col, err := e.App.FindCollectionByNameOrId(users)
	if err != nil {
		return err
	}
	u := core.NewRecord(col)
	u.SetEmail(c.Email)
	u.SetVerified(true)
	c.apply(u)
	if err := e.App.Save(u); err != nil {
		return e.BadRequestError("Could not create the account.", err)
	}
	e.App.Logger().Info("account created", "email", u.Email(), "by", e.Auth.Email())
	return e.JSON(http.StatusCreated, view(e.App, u))
}

func admins(app core.App) int {
	n, _ := app.CountRecords(users, dbx.HashExp{"role": roleAdmin})
	return int(n)
}

func update(e *core.RequestEvent) error {
	u, err := e.App.FindRecordById(users, e.Request.PathValue("id"))
	if err != nil {
		return e.NotFoundError("", nil)
	}
	var c changes
	if err := e.BindBody(&c); err != nil {
		return e.BadRequestError("Invalid body.", err)
	}
	if msg := c.validate(false); msg != "" {
		return e.BadRequestError(msg, nil)
	}
	if c.Admin != nil && !*c.Admin && u.GetString("role") == roleAdmin {
		if u.Id == e.Auth.Id {
			return e.BadRequestError("You cannot remove your own administrator role.", nil)
		}
		if admins(e.App) <= 1 {
			return e.BadRequestError("The server needs at least one administrator.", nil)
		}
	}
	c.apply(u)
	if err := e.App.Save(u); err != nil {
		return e.BadRequestError("Could not save the account.", err)
	}
	e.App.Logger().Info("account changed", "email", u.Email(), "by", e.Auth.Email(), "password", c.Password != "")
	return e.JSON(http.StatusOK, view(e.App, u))
}

func remove(e *core.RequestEvent) error {
	u, err := e.App.FindRecordById(users, e.Request.PathValue("id"))
	if err != nil {
		return e.NotFoundError("", nil)
	}
	if u.Id == e.Auth.Id {
		return e.BadRequestError("You cannot delete your own account here.", nil)
	}
	if u.GetString("role") == roleAdmin && admins(e.App) <= 1 {
		return e.BadRequestError("The server needs at least one administrator.", nil)
	}
	// Cascades remove the account's files, photos, albums and links.
	if err := e.App.Delete(u); err != nil {
		return err
	}
	e.App.Logger().Info("account deleted", "email", u.Email(), "by", e.Auth.Email())
	return e.NoContent(http.StatusNoContent)
}
