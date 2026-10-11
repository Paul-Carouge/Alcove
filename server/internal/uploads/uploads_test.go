package uploads_test

import (
	"encoding/base64"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
	"github.com/Paul-Carouge/Alcove/server/internal/uploads"
)

const helloSHA256 = "b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9" // "hello world"

type env struct {
	app        *tests.TestApp
	url        string
	alice, bob *core.Record
	aliceTok   string
	bobTok     string
}

func setup(t *testing.T) *env {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	uploads.Register(app, false)
	e := &env{app: app}
	e.alice, e.aliceTok = testutil.User(t, app, "alice@test.local")
	e.bob, e.bobTok = testutil.User(t, app, "bob@test.local")
	e.url = testutil.Server(t, app).URL + uploads.BasePath
	return e
}

func meta(kv ...string) string {
	var parts []string
	for i := 0; i < len(kv); i += 2 {
		parts = append(parts, kv[i]+" "+base64.StdEncoding.EncodeToString([]byte(kv[i+1])))
	}
	return strings.Join(parts, ",")
}

func do(t *testing.T, method, url, token string, headers map[string]string, body string) *http.Response {
	t.Helper()
	req, err := http.NewRequest(method, url, strings.NewReader(body))
	if err != nil {
		t.Fatal(err)
	}
	req.Header.Set("Tus-Resumable", "1.0.0")
	if token != "" {
		req.Header.Set("Authorization", token)
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { _ = res.Body.Close() })
	return res
}

// create starts an upload and returns its absolute URL.
func (e *env) create(t *testing.T, token string, size int, metadata string) string {
	t.Helper()
	res := do(t, http.MethodPost, e.url, token, map[string]string{
		"Upload-Length": strconv.Itoa(size), "Upload-Metadata": metadata,
	}, "")
	if res.StatusCode != http.StatusCreated {
		b, _ := io.ReadAll(res.Body)
		t.Fatalf("create: status %d: %s", res.StatusCode, b)
	}
	return res.Header.Get("Location")
}

func patch(t *testing.T, url, token string, offset int, data string) *http.Response {
	t.Helper()
	return do(t, http.MethodPatch, url, token, map[string]string{
		"Upload-Offset": strconv.Itoa(offset), "Content-Type": "application/offset+octet-stream",
	}, data)
}

func TestUploadCreatesNode(t *testing.T) {
	e := setup(t)
	loc := e.create(t, e.aliceTok, 11, meta("filename", "hello.txt"))

	res := patch(t, loc, e.aliceTok, 0, "hello world")
	if res.StatusCode != http.StatusNoContent {
		t.Fatalf("patch: status %d", res.StatusCode)
	}
	id := res.Header.Get(uploads.NodeHeader)
	node, err := e.app.FindRecordById(drive.Collection, id)
	if err != nil {
		t.Fatalf("node %q not created: %v", id, err)
	}
	if node.GetString("name") != "hello.txt" || node.GetInt("size") != 11 ||
		node.GetString("sha256") != helloSHA256 || node.GetString("owner") != e.alice.Id {
		t.Errorf("unexpected node: %v", node.PublicExport())
	}

	entries, _ := os.ReadDir(filepath.Join(e.app.DataDir(), "uploads"))
	if len(entries) != 0 {
		t.Errorf("partial upload files left behind: %d", len(entries))
	}
}

func TestUploadResumes(t *testing.T) {
	e := setup(t)
	loc := e.create(t, e.aliceTok, 11, meta("filename", "hello.txt"))

	if res := patch(t, loc, e.aliceTok, 0, "hello"); res.StatusCode != http.StatusNoContent {
		t.Fatalf("first chunk: %d", res.StatusCode)
	}
	head := do(t, http.MethodHead, loc, e.aliceTok, nil, "")
	if got := head.Header.Get("Upload-Offset"); got != "5" {
		t.Fatalf("offset after first chunk = %q", got)
	}
	res := patch(t, loc, e.aliceTok, 5, " world")
	if res.Header.Get(uploads.NodeHeader) == "" {
		t.Fatalf("no node after the last chunk (status %d)", res.StatusCode)
	}
}

func TestDuplicateNamesAreRenamed(t *testing.T) {
	e := setup(t)
	testutil.Node(t, e.app, e.alice, "", "Hello.txt", drive.KindFile)
	loc := e.create(t, e.aliceTok, 11, meta("filename", "hello.txt"))
	res := patch(t, loc, e.aliceTok, 0, "hello world")
	node, err := e.app.FindRecordById(drive.Collection, res.Header.Get(uploads.NodeHeader))
	if err != nil {
		t.Fatal(err)
	}
	if got := node.GetString("name"); got != "hello (2).txt" {
		t.Errorf("name = %q, want %q", got, "hello (2).txt")
	}
}

func TestUploadIntoFolder(t *testing.T) {
	e := setup(t)
	folder := testutil.Node(t, e.app, e.alice, "", "Docs", drive.KindFolder)
	loc := e.create(t, e.aliceTok, 11, meta("filename", "a.txt", "parent", folder.Id))
	res := patch(t, loc, e.aliceTok, 0, "hello world")
	node, err := e.app.FindRecordById(drive.Collection, res.Header.Get(uploads.NodeHeader))
	if err != nil || node.GetString("parent") != folder.Id {
		t.Fatalf("node not created in folder: %v", err)
	}
}

func TestCreateValidation(t *testing.T) {
	e := setup(t)
	bobFolder := testutil.Node(t, e.app, e.bob, "", "Bob", drive.KindFolder)
	aliceFile := testutil.Node(t, e.app, e.alice, "", "f.txt", drive.KindFile)

	cases := []struct {
		name    string
		token   string
		headers map[string]string
		status  int
	}{
		{"requires authentication", "", map[string]string{"Upload-Length": "1", "Upload-Metadata": meta("filename", "a")}, 401},
		{"rejects invalid names", e.aliceTok, map[string]string{"Upload-Length": "1", "Upload-Metadata": meta("filename", "a/b")}, 400},
		{"rejects missing names", e.aliceTok, map[string]string{"Upload-Length": "1"}, 400},
		{"rejects someone else's folder", e.aliceTok, map[string]string{"Upload-Length": "1", "Upload-Metadata": meta("filename", "a", "parent", bobFolder.Id)}, 400},
		{"rejects a file as parent", e.aliceTok, map[string]string{"Upload-Length": "1", "Upload-Metadata": meta("filename", "a", "parent", aliceFile.Id)}, 400},
		{"requires a known length", e.aliceTok, map[string]string{"Upload-Defer-Length": "1", "Upload-Metadata": meta("filename", "a")}, 400},
		{"rejects files over the size limit", e.aliceTok, map[string]string{"Upload-Length": strconv.FormatInt(drive.MaxFileSize+1, 10), "Upload-Metadata": meta("filename", "a")}, 413},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			if res := do(t, http.MethodPost, e.url, c.token, c.headers, ""); res.StatusCode != c.status {
				t.Errorf("status = %d, want %d", res.StatusCode, c.status)
			}
		})
	}
}

func TestUploadsAreIsolatedPerUser(t *testing.T) {
	e := setup(t)
	loc := e.create(t, e.aliceTok, 11, meta("filename", "secret.txt"))

	for _, method := range []string{http.MethodHead, http.MethodPatch, http.MethodDelete} {
		headers := map[string]string{"Upload-Offset": "0", "Content-Type": "application/offset+octet-stream"}
		if res := do(t, method, loc, e.bobTok, headers, "x"); res.StatusCode != http.StatusNotFound {
			t.Errorf("%s by another user: status %d, want 404", method, res.StatusCode)
		}
	}
	if res := do(t, http.MethodHead, loc, e.aliceTok, nil, ""); res.StatusCode != http.StatusOK {
		t.Errorf("owner HEAD: status %d", res.StatusCode)
	}
}

func TestStaleUploadsAreRemoved(t *testing.T) {
	dir := t.TempDir()
	old, fresh := filepath.Join(dir, "old.bin"), filepath.Join(dir, "fresh.bin")
	for _, p := range []string{old, fresh} {
		if err := os.WriteFile(p, []byte("x"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	past := time.Now().Add(-48 * time.Hour)
	if err := os.Chtimes(old, past, past); err != nil {
		t.Fatal(err)
	}
	if err := uploads.RemoveStaleForTest(dir, time.Now().Add(-24*time.Hour)); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(old); !os.IsNotExist(err) {
		t.Error("stale upload not removed")
	}
	if _, err := os.Stat(fresh); err != nil {
		t.Error("fresh upload removed")
	}
}
