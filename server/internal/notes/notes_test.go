package notes_test

import (
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/types"

	"github.com/Paul-Carouge/Alcove/server/internal/notes"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

const notesURL = "/api/collections/notes/records"

type fixture struct {
	app                   *tests.TestApp
	alice, bob            *core.Record
	aliceToken, bobToken  string
	aliceNote, aliceTagID string
	bobTagID              string
}

func save(tb testing.TB, app core.App, collection string, fields map[string]any) *core.Record {
	tb.Helper()
	col, err := app.FindCollectionByNameOrId(collection)
	if err != nil {
		tb.Fatal(err)
	}
	r := core.NewRecord(col)
	r.Load(fields)
	if err := app.Save(r); err != nil {
		tb.Fatal(err)
	}
	return r
}

func newFixture(tb testing.TB) *fixture {
	app := testutil.NewApp(tb)
	notes.Register(app)
	f := &fixture{app: app}
	f.alice, f.aliceToken = testutil.User(tb, app, "alice@test.local")
	f.bob, f.bobToken = testutil.User(tb, app, "bob@test.local")
	f.aliceNote = save(tb, app, "notes", map[string]any{"owner": f.alice.Id, "title": "Groceries", "body": "- milk"}).Id
	f.aliceTagID = save(tb, app, "tags", map[string]any{"owner": f.alice.Id, "name": "Home", "color": "green"}).Id
	f.bobTagID = save(tb, app, "tags", map[string]any{"owner": f.bob.Id, "name": "Bob's", "color": "red"}).Id
	return f
}

func run(t *testing.T, build func(f *fixture) tests.ApiScenario) {
	t.Helper()
	f := newFixture(t)
	s := build(f)
	s.TestAppFactory = func(testing.TB) *tests.TestApp { return f.app }
	s.Test(t)
}

func auth(token string) map[string]string { return map[string]string{"Authorization": token} }

func body(s string) *strings.Reader { return strings.NewReader(s) }

func TestNotesAreOwnerOnly(t *testing.T) {
	scenarios := []func(f *fixture) tests.ApiScenario{
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "guests see nothing", Method: http.MethodGet, URL: notesURL,
				ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "the owner lists her notes", Method: http.MethodGet, URL: notesURL,
				Headers: auth(f.aliceToken), ExpectedStatus: 200,
				ExpectedContent: []string{`"totalItems":1`, `"title":"Groceries"`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "another user does not see them", Method: http.MethodGet, URL: notesURL,
				Headers: auth(f.bobToken), ExpectedStatus: 200,
				ExpectedContent: []string{`"totalItems":0`}, NotExpectedContent: []string{"Groceries"},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor can open one", Method: http.MethodGet, URL: notesURL + "/" + f.aliceNote,
				Headers: auth(f.bobToken), ExpectedStatus: 404, ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor edit one", Method: http.MethodPatch, URL: notesURL + "/" + f.aliceNote,
				Body: body(`{"body":"hacked"}`), Headers: auth(f.bobToken), ExpectedStatus: 404,
				ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor delete one", Method: http.MethodDelete, URL: notesURL + "/" + f.aliceNote,
				Headers: auth(f.bobToken), ExpectedStatus: 404, ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor create one for her", Method: http.MethodPost, URL: notesURL,
				Body: body(`{"owner":"` + f.alice.Id + `","title":"x"}`), Headers: auth(f.bobToken),
				ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "the owner cannot give a note away", Method: http.MethodPatch, URL: notesURL + "/" + f.aliceNote,
				Body: body(`{"owner":"` + f.bob.Id + `"}`), Headers: auth(f.aliceToken), ExpectedStatus: 404,
				ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "the owner creates a note", Method: http.MethodPost, URL: notesURL,
				Body:    body(`{"owner":"` + f.alice.Id + `","title":"Ideas","body":"# One","pinned":true}`),
				Headers: auth(f.aliceToken), ExpectedStatus: 200,
				ExpectedContent: []string{`"title":"Ideas"`, `"pinned":true`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "and edits it, trash included", Method: http.MethodPatch, URL: notesURL + "/" + f.aliceNote,
				Body:    body(`{"body":"- eggs","trashed_at":"2026-10-15 10:00:00.000Z"}`),
				Headers: auth(f.aliceToken), ExpectedStatus: 200,
				ExpectedContent: []string{`"body":"- eggs"`, `"trashed_at":"2026-10-15 10:00:00.000Z"`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "own tags can be put on a note", Method: http.MethodPatch, URL: notesURL + "/" + f.aliceNote,
				Body: body(`{"tags":["` + f.aliceTagID + `"]}`), Headers: auth(f.aliceToken),
				ExpectedStatus: 200, ExpectedContent: []string{`"tags":["` + f.aliceTagID + `"]`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "someone else's tag is refused", Method: http.MethodPatch, URL: notesURL + "/" + f.aliceNote,
				Body: body(`{"tags":["` + f.bobTagID + `"]}`), Headers: auth(f.aliceToken),
				ExpectedStatus: 400, ExpectedContent: []string{`validation_tags_owner`},
			}
		},
	}
	for _, s := range scenarios {
		run(t, s)
	}
}

func TestPurgeTrash(t *testing.T) {
	f := newFixture(t)
	defer f.app.Cleanup()
	old := save(t, f.app, "notes", map[string]any{
		"owner": f.alice.Id, "title": "Old", "trashed_at": types.NowDateTime().Add(-40 * 24 * time.Hour),
	})
	recent := save(t, f.app, "notes", map[string]any{"owner": f.alice.Id, "title": "Recent", "trashed_at": types.NowDateTime()})

	n, err := notes.PurgeTrash(f.app, time.Now().Add(-30*24*time.Hour))
	if err != nil || n != 1 {
		t.Fatalf("purged %d, %v; want 1", n, err)
	}
	if _, err := f.app.FindRecordById("notes", old.Id); err == nil {
		t.Error("old trashed note still there")
	}
	for _, id := range []string{recent.Id, f.aliceNote} {
		if _, err := f.app.FindRecordById("notes", id); err != nil {
			t.Errorf("note %s purged too early: %v", id, err)
		}
	}
}

// Deleting a tag removes it from notes, as from files.
func TestDeletingATagUntagsNotes(t *testing.T) {
	f := newFixture(t)
	defer f.app.Cleanup()
	note, _ := f.app.FindRecordById("notes", f.aliceNote)
	note.Set("tags", []string{f.aliceTagID})
	if err := f.app.Save(note); err != nil {
		t.Fatal(err)
	}
	tag, _ := f.app.FindRecordById("tags", f.aliceTagID)
	if err := f.app.Delete(tag); err != nil {
		t.Fatal(err)
	}
	got, _ := f.app.FindRecordById("notes", f.aliceNote)
	if tags := got.GetStringSlice("tags"); len(tags) != 0 {
		t.Errorf("tags = %v", tags)
	}
}
