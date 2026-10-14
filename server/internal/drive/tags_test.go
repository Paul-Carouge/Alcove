package drive_test

import (
	"net/http"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
)

func tag(t *testing.T, f *fixture, owner *core.Record, name string) *core.Record {
	t.Helper()
	col, err := f.app.FindCollectionByNameOrId("tags")
	if err != nil {
		t.Fatal(err)
	}
	r := core.NewRecord(col)
	r.Set("owner", owner.Id)
	r.Set("name", name)
	r.Set("color", "blue")
	if err := f.app.Save(r); err != nil {
		t.Fatal(err)
	}
	return r
}

func TestTags(t *testing.T) {
	run(t, func(f *fixture) tests.ApiScenario {
		mine := tag(t, f, f.alice, "Invoices")
		return tests.ApiScenario{
			Name: "own tags can be put on a file", Method: http.MethodPatch, URL: nodesURL + "/" + f.file.Id,
			Body: jsonBody(`{"tags":["` + mine.Id + `"]}`), Headers: auth(f.aliceToken),
			ExpectedStatus: 200, ExpectedContent: []string{`"tags":["` + mine.Id + `"]`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		theirs := tag(t, f, f.bob, "Bob's")
		return tests.ApiScenario{
			Name: "someone else's tag is refused", Method: http.MethodPatch, URL: nodesURL + "/" + f.file.Id,
			Body: jsonBody(`{"tags":["` + theirs.Id + `"]}`), Headers: auth(f.aliceToken),
			ExpectedStatus: 400, ExpectedContent: []string{`validation_tags_owner`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		tag(t, f, f.alice, "Taxes")
		return tests.ApiScenario{
			Name: "names are unique per person, case-insensitively", Method: http.MethodPost, URL: "/api/collections/tags/records",
			Body: jsonBody(`{"owner":"` + f.alice.Id + `","name":"taxes","color":"red"}`), Headers: auth(f.aliceToken),
			ExpectedStatus: 400, ExpectedContent: []string{`"name"`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "tags cannot be created for someone else", Method: http.MethodPost, URL: "/api/collections/tags/records",
			Body: jsonBody(`{"owner":"` + f.bob.Id + `","name":"x","color":"red"}`), Headers: auth(f.aliceToken),
			ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		tag(t, f, f.bob, "Private")
		return tests.ApiScenario{
			Name: "and others' tags are invisible", Method: http.MethodGet, URL: "/api/collections/tags/records",
			Headers: auth(f.aliceToken), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		}
	})
}

func TestDeletingATagUntagsFiles(t *testing.T) {
	f := newFixture(t)
	defer f.app.Cleanup()
	a, b := tag(t, f, f.alice, "A"), tag(t, f, f.alice, "B")
	f.file.Set("tags", []string{a.Id, b.Id})
	if err := f.app.Save(f.file); err != nil {
		t.Fatal(err)
	}
	if err := f.app.Delete(a); err != nil {
		t.Fatal(err)
	}
	got, _ := f.app.FindRecordById("nodes", f.file.Id)
	if tags := got.GetStringSlice("tags"); len(tags) != 1 || tags[0] != b.Id {
		t.Errorf("tags = %v", tags)
	}
}
