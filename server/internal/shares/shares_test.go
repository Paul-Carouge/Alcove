package shares_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/url"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/shares"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

// Alice: /Docs (folder) ⊃ Sub ⊃ deep.txt, /Docs/a.txt, and /private.txt outside.
type env struct {
	app                      *tests.TestApp
	srv                      string
	alice, bob               *core.Record
	aliceTok, bobTok         string
	docs, sub, a, deep, priv *core.Record
}

func setup(t *testing.T) *env {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	shares.Register(app)
	e := &env{app: app}
	e.alice, e.aliceTok = testutil.User(t, app, "alice@test.local")
	e.bob, e.bobTok = testutil.User(t, app, "bob@test.local")
	e.docs = testutil.Node(t, app, e.alice, "", "Docs", drive.KindFolder)
	e.sub = testutil.Node(t, app, e.alice, e.docs.Id, "Sub", drive.KindFolder)
	e.a = fileNode(t, app, e.alice, e.docs.Id, "a.txt", "alpha")
	e.deep = fileNode(t, app, e.alice, e.sub.Id, "deep.txt", "deep content")
	e.priv = fileNode(t, app, e.alice, "", "private.txt", "secret")
	e.srv = testutil.Server(t, app).URL
	return e
}

func fileNode(t *testing.T, app core.App, owner *core.Record, parent, name, content string) *core.Record {
	t.Helper()
	n := testutil.Node(t, app, owner, parent, name, drive.KindFile)
	f, err := filesystem.NewFileFromBytes([]byte(content), name)
	if err != nil {
		t.Fatal(err)
	}
	n.Set("blob", f)
	if err := app.Save(n); err != nil {
		t.Fatal(err)
	}
	return n
}

func (e *env) req(t *testing.T, method, path, token string, body any) (int, map[string]any, string) {
	t.Helper()
	var r io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		r = strings.NewReader(string(b))
	}
	req, _ := http.NewRequest(method, e.srv+path, r)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	raw, _ := io.ReadAll(res.Body)
	var out map[string]any
	_ = json.Unmarshal(raw, &out)
	return res.StatusCode, out, string(raw)
}

func (e *env) share(t *testing.T, body map[string]any) string {
	t.Helper()
	status, out, raw := e.req(t, http.MethodPost, "/api/v1/shares", e.aliceTok, body)
	if status != http.StatusCreated {
		t.Fatalf("create share: %d %s", status, raw)
	}
	return out["token"].(string)
}

func pub(token, rest string) string { return "/api/v1/public/shares/" + url.PathEscape(token) + rest }

func TestCreateValidation(t *testing.T) {
	e := setup(t)
	future := time.Now().Add(48 * time.Hour).UTC().Format(time.RFC3339)
	cases := []struct {
		name   string
		token  string
		body   map[string]any
		status int
	}{
		{"owner can share a folder", e.aliceTok, map[string]any{"node": e.docs.Id}, 201},
		{"with expiry and password", e.aliceTok, map[string]any{"node": e.a.Id, "expiresAt": future, "password": "hunter22"}, 201},
		{"requires authentication", "", map[string]any{"node": e.a.Id}, 401},
		{"cannot share someone else's node", e.bobTok, map[string]any{"node": e.a.Id}, 400},
		{"expiry must be in the future", e.aliceTok, map[string]any{"node": e.a.Id, "expiresAt": "2001-01-01T00:00:00Z"}, 400},
		{"expiry at most a year ahead", e.aliceTok, map[string]any{"node": e.a.Id, "expiresAt": time.Now().AddDate(2, 0, 0).Format(time.RFC3339)}, 400},
		{"password too short", e.aliceTok, map[string]any{"node": e.a.Id, "password": "abc"}, 400},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if status, _, raw := e.req(t, http.MethodPost, "/api/v1/shares", c.token, c.body); status != c.status {
				t.Errorf("status %d, want %d: %s", status, c.status, raw)
			}
		})
	}
}

func TestTokenIsStoredHashedAndHidden(t *testing.T) {
	e := setup(t)
	token := e.share(t, map[string]any{"node": e.a.Id})
	_, out, raw := e.req(t, http.MethodGet, "/api/collections/shares/records", e.aliceTok, nil)
	if strings.Contains(raw, token) || strings.Contains(raw, "token_hash") || strings.Contains(raw, "access_secret") {
		t.Fatalf("secrets exposed through the collection API: %s", raw)
	}
	if out["totalItems"].(float64) != 1 {
		t.Fatalf("owner should see their share: %s", raw)
	}
	if _, out, _ := e.req(t, http.MethodGet, "/api/collections/shares/records", e.bobTok, nil); out["totalItems"].(float64) != 0 {
		t.Fatal("another user can list the share")
	}
}

func TestFolderShareBrowsingStaysInside(t *testing.T) {
	e := setup(t)
	token := e.share(t, map[string]any{"node": e.docs.Id})

	status, out, raw := e.req(t, http.MethodGet, pub(token, ""), "", nil)
	if status != 200 || !strings.Contains(raw, `"a.txt"`) || !strings.Contains(raw, `"Sub"`) {
		t.Fatalf("root listing: %d %s", status, raw)
	}
	if strings.Contains(raw, "owner") || strings.Contains(raw, "blob") {
		t.Errorf("internal fields leaked: %s", raw)
	}
	_ = out

	status, _, raw = e.req(t, http.MethodGet, pub(token, "?folder="+e.sub.Id), "", nil)
	if status != 200 || !strings.Contains(raw, `"deep.txt"`) {
		t.Fatalf("subfolder listing: %d %s", status, raw)
	}

	for name, path := range map[string]string{
		"file inside the share":      pub(token, "/files/"+e.deep.Id),
		"file outside the share":     pub(token, "/files/"+e.priv.Id),
		"folder outside (as folder)": pub(token, "?folder="+e.priv.Id),
	} {
		status, _, body := e.req(t, http.MethodGet, path, "", nil)
		want := 404
		if name == "file inside the share" {
			want = 200
			if body != "deep content" {
				t.Errorf("download body = %q", body)
			}
		}
		if status != want {
			t.Errorf("%s: status %d, want %d", name, status, want)
		}
	}
}

func TestPasswordProtectedShare(t *testing.T) {
	e := setup(t)
	token := e.share(t, map[string]any{"node": e.a.Id, "password": "correct horse"})

	status, out, _ := e.req(t, http.MethodGet, pub(token, ""), "", nil)
	if status != 401 || out["data"].(map[string]any)["requiresPassword"] != true {
		t.Fatalf("locked describe: %d %v", status, out)
	}
	if status, _, _ := e.req(t, http.MethodGet, pub(token, "/files/"+e.a.Id), "", nil); status != 401 {
		t.Errorf("locked download: %d", status)
	}
	if status, _, _ := e.req(t, http.MethodPost, pub(token, "/unlock"), "", map[string]any{"password": "wrong"}); status != 401 {
		t.Errorf("wrong password: %d", status)
	}
	status, out, raw := e.req(t, http.MethodPost, pub(token, "/unlock"), "", map[string]any{"password": "correct horse"})
	if status != 200 {
		t.Fatalf("unlock: %d %s", status, raw)
	}
	access := url.QueryEscape(out["access"].(string))
	if status, _, _ := e.req(t, http.MethodGet, pub(token, "?access="+access), "", nil); status != 200 {
		t.Errorf("describe with access: %d", status)
	}
	if status, _, body := e.req(t, http.MethodGet, pub(token, "/files/"+e.a.Id+"?access="+access), "", nil); status != 200 || body != "alpha" {
		t.Errorf("download with access: %d %q", status, body)
	}

	// An access token from another share is useless here.
	other := e.share(t, map[string]any{"node": e.priv.Id, "password": "other pass"})
	_, out, _ = e.req(t, http.MethodPost, pub(other, "/unlock"), "", map[string]any{"password": "other pass"})
	foreign := url.QueryEscape(out["access"].(string))
	if status, _, _ := e.req(t, http.MethodGet, pub(token, "?access="+foreign), "", nil); status != 401 {
		t.Errorf("foreign access token accepted: %d", status)
	}
}

func TestExpiredTrashedAndRevokedLinks(t *testing.T) {
	e := setup(t)
	token := e.share(t, map[string]any{"node": e.a.Id})
	share, err := e.app.FindFirstRecordByData(shares.Collection, "node", e.a.Id)
	if err != nil {
		t.Fatal(err)
	}

	share.Set("expires_at", time.Now().Add(-time.Minute))
	if err := e.app.Save(share); err != nil {
		t.Fatal(err)
	}
	if status, _, _ := e.req(t, http.MethodGet, pub(token, ""), "", nil); status != 410 {
		t.Errorf("expired: %d, want 410", status)
	}

	share.Set("expires_at", "")
	_ = e.app.Save(share)
	e.a.Set("trashed_at", time.Now())
	_ = e.app.Save(e.a)
	if status, _, _ := e.req(t, http.MethodGet, pub(token, ""), "", nil); status != 404 {
		t.Errorf("trashed node: %d, want 404", status)
	}

	e.a.Set("trashed_at", "")
	_ = e.app.Save(e.a)
	if status, _, _ := e.req(t, http.MethodDelete, "/api/collections/shares/records/"+share.Id, e.aliceTok, nil); status != 204 {
		t.Fatalf("revoke: %d", status)
	}
	if status, _, _ := e.req(t, http.MethodGet, pub(token, ""), "", nil); status != 404 {
		t.Errorf("revoked: %d, want 404", status)
	}
	if status, _, _ := e.req(t, http.MethodGet, pub("not-a-real-token-at-all", ""), "", nil); status != 404 {
		t.Errorf("unknown token: %d", status)
	}
}
