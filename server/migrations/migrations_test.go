package migrations_test

import (
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	_ "github.com/Paul-Carouge/Alcove/server/migrations"
)

func find(t *testing.T, file string) *core.Migration {
	t.Helper()
	for _, mig := range core.AppMigrations.Items() {
		if mig.File == file {
			return mig
		}
	}
	t.Fatalf("migration %s not registered", file)
	return nil
}

// Every app migration must revert and re-apply cleanly. The test app has
// already applied them all, so: down newest-first, then up oldest-first, twice.
func TestMigrationsAreReversible(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	migs := core.AppMigrations.Items()
	for round := range 2 {
		for i := len(migs) - 1; i >= 0; i-- {
			if err := migs[i].Down(app); err != nil {
				t.Fatalf("round %d: down %s: %v", round, migs[i].File, err)
			}
		}
		for _, mig := range migs {
			if err := mig.Up(app); err != nil {
				t.Fatalf("round %d: up %s: %v", round, mig.File, err)
			}
		}
	}
}

func TestUsersLockdown(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()

	mig := find(t, "1791680400_users_lockdown.go")
	if err := mig.Up(app); err != nil {
		t.Fatal(err)
	}
	users, err := app.FindCollectionByNameOrId("users")
	if err != nil {
		t.Fatal(err)
	}
	if users.CreateRule != nil {
		t.Errorf("public sign-up still allowed: createRule = %q", *users.CreateRule)
	}
	if !strings.Contains(users.ResetPasswordTemplate.Body, "{APP_URL}/reset-password/{TOKEN}") {
		t.Errorf("reset template not pointing to the web app:\n%s", users.ResetPasswordTemplate.Body)
	}
}

func TestImportsMigration(t *testing.T) {
	app, err := tests.NewTestApp()
	if err != nil {
		t.Fatal(err)
	}
	defer app.Cleanup()
	hasRule := func() bool {
		for _, r := range app.Settings().RateLimits.Rules {
			if r.Label == "/api/v1/imports/" {
				return true
			}
		}
		return false
	}
	check := func(up bool) {
		t.Helper()
		media, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			t.Fatal(err)
		}
		_, err = app.FindCollectionByNameOrId("imports")
		if (err == nil) != up || (media.Fields.GetByName("import_taken_at") != nil) != up || hasRule() != up {
			t.Errorf("up=%v: imports %v, media field %v, rate limit %v", up, err, media.Fields.GetByName("import_taken_at"), hasRule())
		}
	}
	check(true)
	imports, _ := app.FindCollectionByNameOrId("imports")
	if imports.CreateRule != nil || imports.UpdateRule != nil || imports.DeleteRule != nil {
		t.Error("imports must be written by the server only")
	}
	mig := find(t, "1791745200_imports.go")
	if err := mig.Down(app); err != nil {
		t.Fatal(err)
	}
	check(false)
	if err := mig.Up(app); err != nil {
		t.Fatal(err)
	}
	check(true)
}
