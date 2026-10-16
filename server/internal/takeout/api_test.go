package takeout_test

import (
	"encoding/base64"
	"encoding/json"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	"github.com/Paul-Carouge/Alcove/server/internal/albums"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/takeout"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
	"github.com/Paul-Carouge/Alcove/server/internal/uploads"
)

type apiEnv struct {
	app                       *tests.TestApp
	srv                       string
	alice, bob, admin         *core.Record
	aliceTok, bobTok, adminTk string
}

func setup(t *testing.T) *apiEnv {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	media.Register(app)
	albums.Register(app)
	uploads.Register(app, false)
	r := takeout.NewRunner(app)
	r.Workers = 1
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		takeout.Routes(r, se)
		return se.Next()
	}) // routes only: no job runs, so states stay predictable
	e := &apiEnv{app: app}
	e.alice, e.aliceTok = testutil.User(t, app, "alice@test.local")
	e.bob, e.bobTok = testutil.User(t, app, "bob@test.local")
	e.admin, e.adminTk = testutil.User(t, app, "admin@test.local")
	e.admin.Set("role", "admin")
	if err := app.Save(e.admin); err != nil {
		t.Fatal(err)
	}
	dir := filepath.Join(app.DataDir(), takeout.ServerDir)
	if err := os.MkdirAll(filepath.Join(dir, "extracted"), 0o750); err != nil {
		t.Fatal(err)
	}
	for name, data := range map[string]string{"takeout-1.zip": "PK", ".hidden.zip": "PK", "notes.txt": "x"} {
		if err := os.WriteFile(filepath.Join(dir, name), []byte(data), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	if err := os.Symlink("/etc", filepath.Join(dir, "link")); err != nil {
		t.Fatal(err)
	}
	e.srv = testutil.Server(t, app).URL
	return e
}

func (e *apiEnv) call(t *testing.T, method, path, token, body string) (int, map[string]any) {
	t.Helper()
	req, _ := http.NewRequest(method, e.srv+path, strings.NewReader(body))
	req.Header.Set("Authorization", token)
	req.Header.Set("Content-Type", "application/json")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	var out map[string]any
	_ = json.NewDecoder(res.Body).Decode(&out)
	return res.StatusCode, out
}

func TestServerFilesAdminOnly(t *testing.T) {
	e := setup(t)
	if code, _ := e.call(t, http.MethodGet, "/api/v1/imports/google/server-files", e.aliceTok, ""); code != http.StatusForbidden {
		t.Errorf("user: %d", code)
	}
	if code, _ := e.call(t, http.MethodGet, "/api/v1/imports/google/server-files", "", ""); code != http.StatusUnauthorized {
		t.Errorf("anonymous: %d", code)
	}
	code, out := e.call(t, http.MethodGet, "/api/v1/imports/google/server-files", e.adminTk, "")
	if code != http.StatusOK {
		t.Fatalf("admin: %d", code)
	}
	b, _ := json.Marshal(out["items"])
	if s := string(b); !strings.Contains(s, `"takeout-1.zip"`) || !strings.Contains(s, `"extracted"`) ||
		strings.Contains(s, "hidden") || strings.Contains(s, "notes.txt") || strings.Contains(s, `"link"`) {
		t.Errorf("items = %s", s)
	}
}

func TestCreateImportPermissions(t *testing.T) {
	e := setup(t)
	post := func(token, body string) (int, map[string]any) {
		return e.call(t, http.MethodPost, "/api/v1/imports/google", token, body)
	}
	for _, tt := range []struct {
		name, token, body string
		want              int
	}{
		{"nothing", e.aliceTok, `{}`, 400},
		{"both", e.adminTk, `{"uploads":["abc"],"serverFiles":["takeout-1.zip"]}`, 400},
		{"server files by a user", e.aliceTok, `{"serverFiles":["takeout-1.zip"]}`, 403},
		{"user field by a user", e.aliceTok, `{"uploads":["abc"],"user":"x"}`, 403},
		{"user with uploads", e.adminTk, `{"uploads":["abc"],"user":"x"}`, 400},
		{"unknown upload", e.aliceTok, `{"uploads":["abc"]}`, 400},
		{"upload path", e.aliceTok, `{"uploads":["../../x"]}`, 400},
		{"traversal", e.adminTk, `{"serverFiles":["../data.db"]}`, 400},
		{"symbolic link", e.adminTk, `{"serverFiles":["link"]}`, 400},
		{"not a zip", e.adminTk, `{"serverFiles":["notes.txt"]}`, 400},
		{"unknown user", e.adminTk, `{"serverFiles":["takeout-1.zip"],"user":"nobody"}`, 400},
		{"anonymous", "", `{"uploads":["abc"]}`, 401},
	} {
		if code, _ := post(tt.token, tt.body); code != tt.want {
			t.Errorf("%s: %d, want %d", tt.name, code, tt.want)
		}
	}

	// An administrator imports for Alice; Alice can read and cancel it, Bob cannot see it.
	code, job := post(e.adminTk, `{"serverFiles":["takeout-1.zip"],"user":"`+e.alice.Id+`"}`)
	if code != http.StatusCreated || job["owner"] != e.alice.Id || job["status"] != "queued" || job["created_by"] != e.admin.Id {
		t.Fatalf("create: %d %v", code, job)
	}
	if code, _ := post(e.adminTk, `{"serverFiles":["extracted"],"user":"`+e.alice.Id+`"}`); code != http.StatusConflict {
		t.Errorf("second unfinished import: %d", code)
	}
	id := job["id"].(string)
	for tok, want := range map[string]int{e.aliceTok: 1, e.adminTk: 1, e.bobTok: 0} {
		_, out := e.call(t, http.MethodGet, "/api/collections/imports/records", tok, "")
		if n := int(out["totalItems"].(float64)); n != want {
			t.Errorf("list: %d items, want %d", n, want)
		}
	}
	if code, _ := e.call(t, http.MethodPost, "/api/v1/imports/"+id+"/cancel", e.bobTok, ""); code != http.StatusNotFound {
		t.Errorf("cancel by bob: %d", code)
	}
	if code, _ := e.call(t, http.MethodPost, "/api/v1/imports/"+id+"/cancel", e.aliceTok, ""); code != http.StatusNoContent {
		t.Errorf("cancel by alice: %d", code)
	}
	if code, _ := e.call(t, http.MethodPost, "/api/v1/imports/"+id+"/cancel", e.aliceTok, ""); code != http.StatusConflict {
		t.Errorf("cancel twice: %d", code)
	}
	// Users cannot write jobs through the record API.
	if code, _ := e.call(t, http.MethodPost, "/api/collections/imports/records", e.aliceTok,
		`{"owner":"`+e.alice.Id+`","source":"upload","status":"queued"}`); code == http.StatusOK {
		t.Error("job created through the record API")
	}
}

func tusMeta(kv ...string) string {
	var parts []string
	for i := 0; i < len(kv); i += 2 {
		parts = append(parts, kv[i]+" "+base64.StdEncoding.EncodeToString([]byte(kv[i+1])))
	}
	return strings.Join(parts, ",")
}

func TestImportUploadIsNotADriveFile(t *testing.T) {
	e := setup(t)
	tus := func(method, url string, headers map[string]string, body string) *http.Response {
		req, _ := http.NewRequest(method, url, strings.NewReader(body))
		req.Header.Set("Tus-Resumable", "1.0.0")
		req.Header.Set("Authorization", e.aliceTok)
		for k, v := range headers {
			req.Header.Set(k, v)
		}
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		_ = res.Body.Close()
		return res
	}
	data := "PK fake zip"
	res := tus(http.MethodPost, e.srv+uploads.BasePath, map[string]string{
		"Upload-Length": strconv.Itoa(len(data)), "Upload-Metadata": tusMeta("filename", "notes.txt", "purpose", "import"),
	}, "")
	if res.StatusCode != http.StatusBadRequest {
		t.Errorf("non-zip import upload: %d", res.StatusCode)
	}
	res = tus(http.MethodPost, e.srv+uploads.BasePath, map[string]string{
		"Upload-Length": strconv.Itoa(len(data)), "Upload-Metadata": tusMeta("filename", "takeout-001.zip", "purpose", "import"),
	}, "")
	if res.StatusCode != http.StatusCreated {
		t.Fatalf("create: %d", res.StatusCode)
	}
	loc := res.Header.Get("Location")
	res = tus(http.MethodPatch, loc, map[string]string{"Upload-Offset": "0", "Content-Type": "application/offset+octet-stream"}, data)
	if res.StatusCode != http.StatusNoContent || res.Header.Get(uploads.NodeHeader) != "" {
		t.Fatalf("patch: %d, node %q", res.StatusCode, res.Header.Get(uploads.NodeHeader))
	}
	id := loc[strings.LastIndex(loc, "/")+1:]
	got, err := os.ReadFile(filepath.Join(e.app.DataDir(), takeout.UploadDir, e.alice.Id, id+".zip"))
	if err != nil || string(got) != data {
		t.Fatalf("stored archive: %q %v", got, err)
	}
	if n, _ := e.app.CountRecords(drive.Collection); n != 0 {
		t.Errorf("%d drive nodes created", n)
	}
	// Only Alice can start an import with it.
	if code, _ := e.call(t, http.MethodPost, "/api/v1/imports/google", e.bobTok, `{"uploads":["`+id+`"]}`); code != http.StatusBadRequest {
		t.Errorf("bob used alice's upload: %d", code)
	}
	if code, job := e.call(t, http.MethodPost, "/api/v1/imports/google", e.aliceTok, `{"uploads":["`+id+`"]}`); code != http.StatusCreated || job["source"] != "upload" {
		t.Errorf("alice: %d %v", code, job)
	}
}

func TestStoredUploadsAndLimits(t *testing.T) {
	e := setup(t)
	tus := func(token string, size int, meta string) *http.Response {
		req, _ := http.NewRequest(http.MethodPost, e.srv+uploads.BasePath, nil)
		req.Header.Set("Tus-Resumable", "1.0.0")
		req.Header.Set("Authorization", token)
		req.Header.Set("Upload-Length", strconv.Itoa(size))
		req.Header.Set("Upload-Metadata", meta)
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		_ = res.Body.Close()
		return res
	}
	// With a quota, import archives may not exceed what is left of it.
	e.bob.Set("quota_bytes", 10)
	if err := e.app.Save(e.bob); err != nil {
		t.Fatal(err)
	}
	if res := tus(e.bobTok, 11, tusMeta("filename", "t.zip", "purpose", "import")); res.StatusCode != http.StatusRequestEntityTooLarge {
		t.Errorf("over the quota left: %d", res.StatusCode)
	}

	// Finished archives are listed with their names, can be deleted, and others cannot see them.
	if err := takeout.StoreUpload(e.app, e.alice.Id, "abc123", "takeout-001.zip", writeTemp(t, "PK")); err != nil {
		t.Fatal(err)
	}
	_, out := e.call(t, http.MethodGet, "/api/v1/imports/google/uploads", e.aliceTok, "")
	b, _ := json.Marshal(out["items"])
	if !strings.Contains(string(b), `"name":"takeout-001.zip"`) || !strings.Contains(string(b), `"id":"abc123"`) {
		t.Errorf("alice's uploads = %s", b)
	}
	_, out = e.call(t, http.MethodGet, "/api/v1/imports/google/uploads", e.bobTok, "")
	if b, _ := json.Marshal(out["items"]); string(b) != "[]" {
		t.Errorf("bob sees %s", b)
	}
	if code, _ := e.call(t, http.MethodDelete, "/api/v1/imports/google/uploads/abc123", e.bobTok, ""); code != http.StatusNotFound {
		t.Errorf("bob deleted alice's archive: %d", code)
	}
	// In use by a job: kept (and hidden from the list).
	code, job := e.call(t, http.MethodPost, "/api/v1/imports/google", e.aliceTok, `{"uploads":["abc123"]}`)
	if code != http.StatusCreated {
		t.Fatalf("create: %d", code)
	}
	if code, _ := e.call(t, http.MethodDelete, "/api/v1/imports/google/uploads/abc123", e.aliceTok, ""); code != http.StatusConflict {
		t.Errorf("delete while used: %d", code)
	}
	// An administrator can cancel anyone's import.
	if code, _ := e.call(t, http.MethodPost, "/api/v1/imports/"+job["id"].(string)+"/cancel", e.adminTk, ""); code != http.StatusNoContent {
		t.Errorf("admin cancel: %d", code)
	}
	if code, _ := e.call(t, http.MethodDelete, "/api/v1/imports/google/uploads/abc123", e.aliceTok, ""); code != http.StatusNoContent {
		t.Errorf("delete: %d", code)
	}
	if code, _ := e.call(t, http.MethodDelete, "/api/v1/imports/google/uploads/..%2Fx", e.aliceTok, ""); code != http.StatusNotFound {
		t.Errorf("traversal: %d", code)
	}
}

func writeTemp(t *testing.T, data string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "bin")
	if err := os.WriteFile(p, []byte(data), 0o600); err != nil {
		t.Fatal(err)
	}
	return p
}

// Concurrent creations cannot exceed the import allowance together.
func TestConcurrentImportUploadsShareTheAllowance(t *testing.T) {
	e := setup(t)
	e.bob.Set("quota_bytes", 25)
	if err := e.app.Save(e.bob); err != nil {
		t.Fatal(err)
	}
	codes := make(chan int, 6)
	var wg sync.WaitGroup
	for range 6 {
		wg.Go(func() {
			req, _ := http.NewRequest(http.MethodPost, e.srv+uploads.BasePath, nil)
			req.Header.Set("Tus-Resumable", "1.0.0")
			req.Header.Set("Authorization", e.bobTok)
			req.Header.Set("Upload-Length", "10")
			req.Header.Set("Upload-Metadata", tusMeta("filename", "t.zip", "purpose", "import"))
			res, err := http.DefaultClient.Do(req)
			if err != nil {
				t.Error(err)
				return
			}
			_ = res.Body.Close()
			codes <- res.StatusCode
		})
	}
	wg.Wait()
	close(codes)
	created := 0
	for c := range codes {
		if c == http.StatusCreated {
			created++
		}
	}
	if created != 2 {
		t.Errorf("%d uploads of 10 bytes created within a 25-byte allowance, want 2", created)
	}
}
