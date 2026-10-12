package drive_test

import (
	"crypto/sha256"
	"encoding/hex"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

func sum(s string) string {
	h := sha256.Sum256([]byte(s))
	return hex.EncodeToString(h[:])
}

func TestKnownHashes(t *testing.T) {
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	alice, aliceTok := testutil.User(t, app, "alice@test.local")
	bob, _ := testutil.User(t, app, "bob@test.local")
	file := func(owner string, content string, trashed bool) {
		u, _ := app.FindRecordById("users", owner)
		n := testutil.Node(t, app, u, "", content+".jpg", drive.KindFile)
		f, _ := filesystem.NewFileFromBytes([]byte(content), content+".jpg")
		n.Set("blob", f)
		if trashed {
			n.Set("trashed_at", time.Now())
		}
		if err := app.Save(n); err != nil {
			t.Fatal(err)
		}
	}
	file(alice.Id, "beach", false)
	file(alice.Id, "old", true) // deleted on the server: still known, not re-uploaded
	file(bob.Id, "bobs", false)

	body := `{"hashes":["` + strings.Join([]string{sum("beach"), sum("old"), sum("bobs"), sum("new")}, `","`) + `"]}`
	scenario := tests.ApiScenario{
		Name: "known hashes are alice's only", Method: http.MethodPost, URL: "/api/v1/backup/known",
		Headers: map[string]string{"Authorization": aliceTok}, Body: strings.NewReader(body),
		TestAppFactory: func(testing.TB) *tests.TestApp { return app }, DisableTestAppCleanup: true,
		ExpectedStatus:     200,
		ExpectedContent:    []string{sum("beach"), sum("old")},
		NotExpectedContent: []string{sum("bobs"), sum("new")},
	}
	scenario.Test(t)
	bad := tests.ApiScenario{
		Name: "invalid hash", Method: http.MethodPost, URL: "/api/v1/backup/known",
		Headers: map[string]string{"Authorization": aliceTok}, Body: strings.NewReader(`{"hashes":["nope' OR 1=1"]}`),
		TestAppFactory: func(testing.TB) *tests.TestApp { return app }, DisableTestAppCleanup: true,
		ExpectedStatus: 400, ExpectedContent: []string{"Invalid hash"},
	}
	bad.Test(t)
	anon := tests.ApiScenario{
		Name: "anonymous", Method: http.MethodPost, URL: "/api/v1/backup/known", Body: strings.NewReader(`{"hashes":[]}`),
		TestAppFactory: func(testing.TB) *tests.TestApp { return app }, DisableTestAppCleanup: true,
		ExpectedStatus: 401, ExpectedContent: []string{`"status":401`},
	}
	anon.Test(t)
}
