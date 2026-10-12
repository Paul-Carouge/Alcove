package updates_test

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"crypto/ed25519"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/pocketbase/pocketbase/tests"

	"github.com/Paul-Carouge/Alcove/server/internal/service"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
	"github.com/Paul-Carouge/Alcove/server/internal/updates"
)

// releaseServer serves a signed release 99.0.0 whose binary contains "NEW".
func releaseServer(t *testing.T) (url, pub string) {
	t.Helper()
	pubKey, priv, _ := ed25519.GenerateKey(rand.Reader)
	goos, arch := updater.Platform()
	name := updater.ArchiveName("99.0.0", goos, arch)
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	exe := "alcove"
	if goos == "windows" {
		t.Skip("tar fixture")
	}
	_ = tw.WriteHeader(&tar.Header{Name: exe, Mode: 0o755, Size: 3, Typeflag: tar.TypeReg})
	_, _ = tw.Write([]byte("NEW"))
	_ = tw.Close()
	_ = gz.Close()
	archive := buf.Bytes()
	sum := sha256.Sum256(archive)
	sums := fmt.Sprintf("%s  %s\n", hex.EncodeToString(sum[:]), name)
	sig := base64.StdEncoding.EncodeToString(ed25519.Sign(priv, []byte(sums)))

	var srv *httptest.Server
	srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/repos/Paul-Carouge/Alcove/releases/latest":
			_ = json.NewEncoder(w).Encode(map[string]any{
				"tag_name": "v99.0.0", "body": "### Added\n- Everything", "html_url": "https://example/99",
				"assets": []map[string]string{
					{"name": name, "browser_download_url": srv.URL + "/a"},
					{"name": updater.SumsAsset, "browser_download_url": srv.URL + "/s"},
					{"name": updater.SigAsset, "browser_download_url": srv.URL + "/g"},
				},
			})
		case "/a":
			_, _ = w.Write(archive)
		case "/s":
			_, _ = w.Write([]byte(sums))
		case "/g":
			_, _ = w.Write([]byte(sig))
		}
	}))
	t.Cleanup(srv.Close)
	return srv.URL, base64.StdEncoding.EncodeToString(pubKey)
}

type env struct {
	app        *tests.TestApp
	srv        string
	admin      string
	user       string
	binary     string
	exitCalled *atomic.Bool
}

func setup(t *testing.T, mode string) *env {
	t.Helper()
	api, pub := releaseServer(t)
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	bin := filepath.Join(t.TempDir(), "alcove")
	_ = os.WriteFile(bin, []byte("OLD"), 0o755)
	var exited atomic.Bool
	updates.Register(app, updates.Options{
		APIBase: api, Mode: mode, PublicKey: pub, Binary: bin,
		Exit: func() { exited.Store(true) },
	})
	admin, adminTok := testutil.User(t, app, "admin@test.local")
	admin.Set("role", "admin")
	if err := app.Save(admin); err != nil {
		t.Fatal(err)
	}
	_, userTok := testutil.User(t, app, "user@test.local")
	return &env{app: app, srv: testutil.Server(t, app).URL, admin: adminTok, user: userTok, binary: bin, exitCalled: &exited}
}

func (e *env) do(t *testing.T, method, path, token string) (int, map[string]any) {
	t.Helper()
	req, _ := http.NewRequest(method, e.srv+path, nil)
	if token != "" {
		req.Header.Set("Authorization", token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	var out map[string]any
	_ = json.NewDecoder(res.Body).Decode(&out)
	return res.StatusCode, out
}

func TestAdminOnly(t *testing.T) {
	e := setup(t, "native")
	if status, _ := e.do(t, http.MethodGet, "/api/v1/admin/system", ""); status != 401 {
		t.Errorf("guest: %d", status)
	}
	if status, _ := e.do(t, http.MethodGet, "/api/v1/admin/system", e.user); status != 403 {
		t.Errorf("regular user: %d", status)
	}
	if status, _ := e.do(t, http.MethodPost, "/api/v1/admin/updates/apply", e.user); status != 403 {
		t.Errorf("regular user apply: %d", status)
	}
}

func TestCheckReportsAvailableUpdate(t *testing.T) {
	e := setup(t, "")
	status, out := e.do(t, http.MethodPost, "/api/v1/admin/updates/check", e.admin)
	if status != 200 {
		t.Fatalf("check: %d %v", status, out)
	}
	u := out["update"].(map[string]any)
	if u["available"] != true || u["latest"] != "99.0.0" || !strings.Contains(u["notes"].(string), "Everything") {
		t.Fatalf("update = %v", u)
	}
	if out["installMode"] != "manual" || out["canSelfUpdate"] != false || out["updateCommand"] == "" {
		t.Errorf("manual install info = %v", out)
	}
}

func TestApplyRefusedWithoutServiceManager(t *testing.T) {
	e := setup(t, "native") // ALCOVE_SERVICE not set: nothing would restart us
	if status, _ := e.do(t, http.MethodPost, "/api/v1/admin/updates/apply", e.admin); status != 400 {
		t.Fatalf("apply: %d", status)
	}
	if b, _ := os.ReadFile(e.binary); string(b) != "OLD" {
		t.Error("binary changed")
	}
}

func TestApplyInstallsVerifiedReleaseAndRestarts(t *testing.T) {
	t.Setenv(service.EnvInstalled, "systemd")
	e := setup(t, "native")
	status, out := e.do(t, http.MethodPost, "/api/v1/admin/updates/apply", e.admin)
	if status != 202 || out["version"] != "99.0.0" {
		t.Fatalf("apply: %d %v", status, out)
	}
	if b, _ := os.ReadFile(e.binary); string(b) != "NEW" {
		t.Errorf("binary = %q", b)
	}
	if b, _ := os.ReadFile(e.binary + ".old"); string(b) != "OLD" {
		t.Error("previous binary not kept")
	}
	backups, _ := filepath.Glob(filepath.Join(e.app.DataDir(), "alcove_backups", "*pre-update-99.0.0.db"))
	if len(backups) != 1 {
		t.Errorf("pre-update backup missing: %v", backups)
	}
	for range 30 {
		if e.exitCalled.Load() {
			return
		}
		testutil.Sleep(100)
	}
	t.Error("the server did not restart")
}
