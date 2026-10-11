package drive_test

import (
	"bytes"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

// fixture: Alice owns /Docs/Sub and /notes.txt (a file); Bob owns /Bob.
type fixture struct {
	app                   *tests.TestApp
	alice, bob            *core.Record
	aliceToken, bobToken  string
	docs, sub, file, bobF *core.Record
}

func newFixture(tb testing.TB) *fixture {
	app := testutil.NewApp(tb)
	drive.Register(app)
	f := &fixture{app: app}
	f.alice, f.aliceToken = testutil.User(tb, app, "alice@test.local")
	f.bob, f.bobToken = testutil.User(tb, app, "bob@test.local")
	f.docs = testutil.Node(tb, app, f.alice, "", "Docs", drive.KindFolder)
	f.sub = testutil.Node(tb, app, f.alice, f.docs.Id, "Sub", drive.KindFolder)
	f.file = testutil.Node(tb, app, f.alice, "", "notes.txt", drive.KindFile)
	f.bobF = testutil.Node(tb, app, f.bob, "", "Bob", drive.KindFolder)
	return f
}

// run builds a fresh fixture per scenario (ApiScenario cleans the app up).
func run(t *testing.T, build func(f *fixture) tests.ApiScenario) {
	t.Helper()
	f := newFixture(t)
	s := build(f)
	s.TestAppFactory = func(testing.TB) *tests.TestApp { return f.app }
	s.Test(t)
}

func jsonBody(s string) *strings.Reader { return strings.NewReader(s) }

func auth(token string) map[string]string { return map[string]string{"Authorization": token} }

const nodesURL = "/api/collections/nodes/records"

func TestAccessControl(t *testing.T) {
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "guests see nothing", Method: http.MethodGet, URL: nodesURL,
			ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "users only list their own nodes", Method: http.MethodGet, URL: nodesURL,
			Headers: auth(f.bobToken), ExpectedStatus: 200,
			ExpectedContent:    []string{`"totalItems":1`, `"name":"Bob"`},
			NotExpectedContent: []string{`"Docs"`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "viewing someone else's node is a 404", Method: http.MethodGet, URL: nodesURL + "/" + f.docs.Id,
			Headers: auth(f.bobToken), ExpectedStatus: 404, ExpectedContent: []string{`"data":{}`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "deleting someone else's node is a 404", Method: http.MethodDelete, URL: nodesURL + "/" + f.docs.Id,
			Headers: auth(f.bobToken), ExpectedStatus: 404, ExpectedContent: []string{`"data":{}`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "guests cannot create", Method: http.MethodPost, URL: nodesURL,
			Body:           jsonBody(`{"owner":"` + f.alice.Id + `","name":"x","kind":"folder"}`),
			ExpectedStatus: 400, ExpectedContent: []string{`"data":{}`},
		}
	})
}

func TestCreateRules(t *testing.T) {
	cases := []struct {
		name   string
		body   func(f *fixture) string
		status int
		want   []string
	}{
		{"create a folder at the root", func(f *fixture) string {
			return `{"owner":"` + f.alice.Id + `","name":"Photos","kind":"folder"}`
		}, 200, []string{`"name":"Photos"`, `"parent":""`}},
		{"create in an own folder", func(f *fixture) string {
			return `{"owner":"` + f.alice.Id + `","parent":"` + f.docs.Id + `","name":"a","kind":"folder"}`
		}, 200, []string{`"parent":"`}},
		{"cannot create for someone else", func(f *fixture) string {
			return `{"owner":"` + f.bob.Id + `","name":"x","kind":"folder"}`
		}, 400, nil},
		{"cannot create in someone else's folder", func(f *fixture) string {
			return `{"owner":"` + f.alice.Id + `","parent":"` + f.bobF.Id + `","name":"x","kind":"folder"}`
		}, 400, nil},
		{"cannot create inside a file", func(f *fixture) string {
			return `{"owner":"` + f.alice.Id + `","parent":"` + f.file.Id + `","name":"x","kind":"folder"}`
		}, 400, nil},
		{"cannot set server-computed fields", func(f *fixture) string {
			return `{"owner":"` + f.alice.Id + `","name":"x","kind":"file","size":1,"sha256":"` + strings.Repeat("a", 64) + `"}`
		}, 400, nil},
		{"names are unique per folder, case-insensitively", func(f *fixture) string {
			return `{"owner":"` + f.alice.Id + `","name":"DOCS","kind":"folder"}`
		}, 400, []string{`"name"`}},
		{"same name allowed in another folder", func(f *fixture) string {
			return `{"owner":"` + f.alice.Id + `","parent":"` + f.docs.Id + `","name":"Docs","kind":"folder"}`
		}, 200, nil},
		{"invalid names are rejected", func(f *fixture) string {
			return `{"owner":"` + f.alice.Id + `","name":"a/b","kind":"folder"}`
		}, 400, []string{`"name"`}},
		{"dot names are rejected", func(f *fixture) string {
			return `{"owner":"` + f.alice.Id + `","name":"..","kind":"folder"}`
		}, 400, []string{`"name"`}},
	}
	for _, c := range cases {
		if c.want == nil {
			c.want = []string{map[int]string{200: `"id":`, 400: `"status":400`}[c.status]}
		}
		run(t, func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: c.name, Method: http.MethodPost, URL: nodesURL,
				Headers: auth(f.aliceToken), Body: jsonBody(c.body(f)),
				ExpectedStatus: c.status, ExpectedContent: c.want,
			}
		})
	}
}

func TestUpdateRules(t *testing.T) {
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "rename and move within own tree", Method: http.MethodPatch, URL: nodesURL + "/" + f.file.Id,
			Headers: auth(f.aliceToken), Body: jsonBody(`{"name":"renamed.txt","parent":"` + f.sub.Id + `"}`),
			ExpectedStatus: 200, ExpectedContent: []string{`"name":"renamed.txt"`, `"parent":"` + f.sub.Id + `"`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "moving a folder inside its own subtree is rejected", Method: http.MethodPatch, URL: nodesURL + "/" + f.docs.Id,
			Headers: auth(f.aliceToken), Body: jsonBody(`{"parent":"` + f.sub.Id + `"}`),
			ExpectedStatus: 400, ExpectedContent: []string{`validation_parent_cycle`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			// A failing update rule answers 404 so it reveals nothing.
			Name: "kind is immutable", Method: http.MethodPatch, URL: nodesURL + "/" + f.docs.Id,
			Headers: auth(f.aliceToken), Body: jsonBody(`{"kind":"file"}`),
			ExpectedStatus: 404, ExpectedContent: []string{`"status":404`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "owner is immutable", Method: http.MethodPatch, URL: nodesURL + "/" + f.docs.Id,
			Headers: auth(f.aliceToken), Body: jsonBody(`{"owner":"` + f.bob.Id + `"}`),
			ExpectedStatus: 404, ExpectedContent: []string{`"status":404`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "a trashed name can be reused", Method: http.MethodPost, URL: nodesURL,
			Headers: auth(f.aliceToken),
			Body:    jsonBody(`{"owner":"` + f.alice.Id + `","name":"Docs","kind":"folder"}`),
			BeforeTestFunc: func(t testing.TB, app *tests.TestApp, _ *core.ServeEvent) {
				f.docs.Set("trashed_at", "2026-01-01 00:00:00.000Z")
				if err := app.Save(f.docs); err != nil {
					t.Fatal(err)
				}
			},
			ExpectedStatus: 200, ExpectedContent: []string{`"name":"Docs"`},
		}
	})
}

func TestUploadComputesMetadata(t *testing.T) {
	run(t, func(f *fixture) tests.ApiScenario {
		body, mp, err := tests.MockMultipartData(map[string]string{
			"owner": f.alice.Id, "name": "hello.txt", "kind": drive.KindFile,
		}, "blob")
		if err != nil {
			t.Fatal(err)
		}
		return tests.ApiScenario{
			Name: "size, mime and sha256 come from the content", Method: http.MethodPost, URL: nodesURL,
			Headers: map[string]string{"Authorization": f.aliceToken, "Content-Type": mp.FormDataContentType()},
			Body:    bytes.NewReader(body.Bytes()), ExpectedStatus: 200,
			ExpectedContent: []string{
				`"size":4`, `"mime":"text/plain; charset=utf-8"`,
				`"sha256":"9f86d081884c7d659a2feaa0c55ad015a3bf4f1b2b0b822cd15d6c15b0f00a08"`,
			},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		body, mp, err := tests.MockMultipartData(map[string]string{
			"owner": f.alice.Id, "name": "dir", "kind": drive.KindFolder,
		}, "blob")
		if err != nil {
			t.Fatal(err)
		}
		return tests.ApiScenario{
			Name: "folders cannot carry file data", Method: http.MethodPost, URL: nodesURL,
			Headers: map[string]string{"Authorization": f.aliceToken, "Content-Type": mp.FormDataContentType()},
			Body:    bytes.NewReader(body.Bytes()), ExpectedStatus: 400,
			ExpectedContent: []string{`validation_folder_blob`},
		}
	})
}

func TestDeleteCascades(t *testing.T) {
	f := newFixture(t)
	defer f.app.Cleanup()
	if err := f.app.Delete(f.docs); err != nil {
		t.Fatal(err)
	}
	if _, err := f.app.FindRecordById(drive.Collection, f.sub.Id); err == nil {
		t.Fatal("child folder survived its parent's deletion")
	}
}

func TestBlobIsProtected(t *testing.T) {
	f := newFixture(t)
	defer f.app.Cleanup()
	col, _ := f.app.FindCollectionByNameOrId(drive.Collection)
	field, ok := col.Fields.GetByName("blob").(*core.FileField)
	if !ok || !field.Protected {
		t.Fatal("blob must be a protected file field (served only with short-lived file tokens)")
	}
}

func TestPurgeTrash(t *testing.T) {
	f := newFixture(t)
	defer f.app.Cleanup()
	now := time.Now()
	trash := func(n *core.Record, at time.Time) {
		n.Set("trashed_at", at)
		if err := f.app.Save(n); err != nil {
			t.Fatal(err)
		}
	}
	trash(f.docs, now.Add(-31*24*time.Hour)) // old: purged with its child "Sub"
	trash(f.file, now.Add(-time.Hour))       // recent: kept

	n, err := drive.PurgeTrash(f.app, now.Add(-drive.TrashRetention))
	if err != nil || n != 1 {
		t.Fatalf("PurgeTrash = %d, %v; want 1, nil", n, err)
	}
	for _, gone := range []*core.Record{f.docs, f.sub} {
		if _, err := f.app.FindRecordById(drive.Collection, gone.Id); err == nil {
			t.Errorf("%s should have been purged", gone.GetString("name"))
		}
	}
	if _, err := f.app.FindRecordById(drive.Collection, f.file.Id); err != nil {
		t.Error("recently trashed file was purged")
	}
}

func TestDownload(t *testing.T) {
	withBlob := func(tb testing.TB, f *fixture) {
		file, err := filesystem.NewFileFromBytes([]byte("report body"), "x.txt")
		if err != nil {
			tb.Fatal(err)
		}
		f.file.Set("name", "Rapport été.txt")
		f.file.Set("blob", file)
		if err := f.app.Save(f.file); err != nil {
			tb.Fatal(err)
		}
	}
	url := func(f *fixture, id string, user *core.Record) string {
		tok := ""
		if user != nil {
			var err error
			if tok, err = user.NewFileToken(); err != nil {
				t.Fatal(err)
			}
		}
		return "/api/v1/nodes/" + id + "/download?token=" + tok
	}

	run(t, func(f *fixture) tests.ApiScenario {
		withBlob(t, f)
		return tests.ApiScenario{
			Name: "owner downloads under the drive name", Method: http.MethodGet, URL: url(f, f.file.Id, f.alice),
			ExpectedStatus: 200, ExpectedContent: []string{"report body"},
			AfterTestFunc: func(t testing.TB, _ *tests.TestApp, res *http.Response) {
				cd := res.Header.Get("Content-Disposition")
				if !strings.HasPrefix(cd, "attachment;") || !strings.Contains(cd, "filename*=utf-8''Rapport%20%C3%A9t%C3%A9.txt") {
					t.Errorf("Content-Disposition = %q", cd)
				}
			},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		withBlob(t, f)
		return tests.ApiScenario{
			Name: "another user gets a 404", Method: http.MethodGet, URL: url(f, f.file.Id, f.bob),
			ExpectedStatus: 404, ExpectedContent: []string{`"status":404`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		withBlob(t, f)
		return tests.ApiScenario{
			Name: "no token is a 401", Method: http.MethodGet, URL: url(f, f.file.Id, nil),
			ExpectedStatus: 401, ExpectedContent: []string{`"status":401`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		withBlob(t, f)
		return tests.ApiScenario{
			Name: "an auth token is not accepted as a file token", Method: http.MethodGet,
			URL:            "/api/v1/nodes/" + f.file.Id + "/download?token=" + f.aliceToken,
			ExpectedStatus: 401, ExpectedContent: []string{`"status":401`},
		}
	})
	run(t, func(f *fixture) tests.ApiScenario {
		return tests.ApiScenario{
			Name: "folders cannot be downloaded", Method: http.MethodGet, URL: url(f, f.docs.Id, f.alice),
			ExpectedStatus: 404, ExpectedContent: []string{`"status":404`},
		}
	})
}
