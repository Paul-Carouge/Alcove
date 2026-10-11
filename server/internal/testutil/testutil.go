// Package testutil builds PocketBase test apps with Alcove's migrations.
package testutil

import (
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	_ "github.com/Paul-Carouge/Alcove/server/migrations"
)

// NewApp returns a fresh app (empty data dir, all migrations applied).
func NewApp(tb testing.TB) *tests.TestApp {
	tb.Helper()
	app, err := tests.NewTestAppWithConfig(core.BaseAppConfig{DataDir: tb.TempDir()})
	if err != nil {
		tb.Fatal(err)
	}
	return app
}

// User creates a verified user and returns it with a valid auth token.
func User(tb testing.TB, app core.App, email string) (*core.Record, string) {
	tb.Helper()
	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		tb.Fatal(err)
	}
	u := core.NewRecord(users)
	u.SetEmail(email)
	u.SetPassword("test-password-123")
	u.SetVerified(true)
	if err := app.Save(u); err != nil {
		tb.Fatal(err)
	}
	token, err := u.NewAuthToken()
	if err != nil {
		tb.Fatal(err)
	}
	return u, token
}

// Node inserts a node directly (bypassing API rules).
func Node(tb testing.TB, app core.App, owner *core.Record, parent, name, kind string) *core.Record {
	tb.Helper()
	col, err := app.FindCollectionByNameOrId("nodes")
	if err != nil {
		tb.Fatal(err)
	}
	n := core.NewRecord(col)
	n.Set("owner", owner.Id)
	n.Set("parent", parent)
	n.Set("name", name)
	n.Set("kind", kind)
	if err := app.Save(n); err != nil {
		tb.Fatal(err)
	}
	return n
}
