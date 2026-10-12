package updater_test

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
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
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

type fakeRelease struct {
	version  string
	archive  []byte
	sums     string
	sig      string
	unsigned bool
}

func tarGz(t *testing.T, name string, content []byte) []byte {
	t.Helper()
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	_ = tw.WriteHeader(&tar.Header{Name: "alcove_dir/" + name, Mode: 0o755, Size: int64(len(content)), Typeflag: tar.TypeReg})
	_, _ = tw.Write(content)
	_ = tw.Close()
	_ = gz.Close()
	return buf.Bytes()
}

// newRelease builds a signed release for the running platform.
func newRelease(t *testing.T, priv ed25519.PrivateKey, version string, binary []byte) *fakeRelease {
	t.Helper()
	goos, arch := updater.Platform()
	if goos == "windows" {
		t.Skip("tar.gz fixture")
	}
	archive := tarGz(t, "alcove", binary)
	sum := sha256.Sum256(archive)
	sums := fmt.Sprintf("%s  %s\n", hex.EncodeToString(sum[:]), updater.ArchiveName(version, goos, arch))
	return &fakeRelease{
		version: version, archive: archive, sums: sums,
		sig: base64.StdEncoding.EncodeToString(ed25519.Sign(priv, []byte(sums))),
	}
}

func serve(t *testing.T, r *fakeRelease) *httptest.Server {
	t.Helper()
	goos, arch := updater.Platform()
	name := updater.ArchiveName(r.version, goos, arch)
	var srv *httptest.Server
	srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, req *http.Request) {
		switch req.URL.Path {
		case "/repos/o/r/releases/latest":
			assets := []map[string]string{{"name": name, "browser_download_url": srv.URL + "/dl/archive"}}
			if !r.unsigned {
				assets = append(assets,
					map[string]string{"name": updater.SumsAsset, "browser_download_url": srv.URL + "/dl/sums"},
					map[string]string{"name": updater.SigAsset, "browser_download_url": srv.URL + "/dl/sig"})
			}
			_ = json.NewEncoder(w).Encode(map[string]any{
				"tag_name": "v" + r.version, "body": "## Notes", "html_url": "https://example/rel", "assets": assets,
			})
		case "/dl/archive":
			_, _ = w.Write(r.archive)
		case "/dl/sums":
			_, _ = w.Write([]byte(r.sums))
		case "/dl/sig":
			_, _ = w.Write([]byte(r.sig))
		default:
			http.NotFound(w, req)
		}
	}))
	t.Cleanup(srv.Close)
	return srv
}

func keys(t *testing.T) (string, ed25519.PrivateKey) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	return base64.StdEncoding.EncodeToString(pub), priv
}

func download(t *testing.T, pub string, r *fakeRelease) (string, error) {
	t.Helper()
	srv := serve(t, r)
	c, err := updater.New(srv.URL, "o/r", pub)
	if err != nil {
		t.Fatal(err)
	}
	rel, err := c.Latest(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if rel.Version != r.version || rel.Notes != "## Notes" {
		t.Fatalf("release = %+v", rel)
	}
	return c.Download(context.Background(), rel, t.TempDir())
}

func TestValidReleaseInstalls(t *testing.T) {
	pub, priv := keys(t)
	path, err := download(t, pub, newRelease(t, priv, "0.9.1", []byte("NEW BINARY")))
	if err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(path); string(b) != "NEW BINARY" {
		t.Fatalf("extracted %q", b)
	}
}

func TestTamperedReleasesAreRefused(t *testing.T) {
	pub, priv := keys(t)
	_, otherPriv := keys(t)

	wrongKey := newRelease(t, otherPriv, "0.9.1", []byte("EVIL"))
	if _, err := download(t, pub, wrongKey); err == nil || !strings.Contains(err.Error(), "signature") {
		t.Errorf("release signed by another key: err = %v", err)
	}

	swapped := newRelease(t, priv, "0.9.1", []byte("GOOD"))
	swapped.archive = tarGz(t, "alcove", []byte("EVIL")) // sums still describe the good archive
	if _, err := download(t, pub, swapped); err == nil || !strings.Contains(err.Error(), "checksum") {
		t.Errorf("swapped archive: err = %v", err)
	}

	unsigned := newRelease(t, priv, "0.9.1", []byte("X"))
	unsigned.unsigned = true
	if _, err := download(t, pub, unsigned); err == nil || !strings.Contains(err.Error(), "not signed") {
		t.Errorf("unsigned release: err = %v", err)
	}
}

func TestNewer(t *testing.T) {
	for _, c := range []struct {
		cur, latest string
		want        bool
	}{
		{"0.8.0", "0.9.0", true},
		{"0.9.0", "0.9.0", false},
		{"0.10.0", "0.9.0", false},
		{"0.8.0-3-gabc123", "0.8.1", true},
		{"0.8.0-3-gabc123-dirty", "0.8.0", false},
		{"0.0.0-dev", "0.1.0", true},
		{"f3cc7b2", "0.1.0", true}, // source build without tags
		{"0.9.0", "not-a-version", false},
	} {
		if got := updater.Newer(c.cur, c.latest); got != c.want {
			t.Errorf("Newer(%q, %q) = %v", c.cur, c.latest, got)
		}
	}
}

func TestReplaceKeepsPreviousBinary(t *testing.T) {
	dir := t.TempDir()
	target := filepath.Join(dir, "alcove")
	newExe := filepath.Join(t.TempDir(), "alcove.new")
	_ = os.WriteFile(target, []byte("OLD"), 0o755)
	_ = os.WriteFile(newExe, []byte("NEW"), 0o755)
	if err := updater.Replace(target, newExe); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(target); string(b) != "NEW" {
		t.Errorf("target = %q", b)
	}
	if b, _ := os.ReadFile(target + ".old"); string(b) != "OLD" {
		t.Errorf("backup = %q", b)
	}
	if info, _ := os.Stat(target); info.Mode().Perm()&0o100 == 0 {
		t.Error("new binary is not executable")
	}
}
