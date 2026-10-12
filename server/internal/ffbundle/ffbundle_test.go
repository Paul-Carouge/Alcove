package ffbundle_test

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

	"github.com/Paul-Carouge/Alcove/server/internal/ffbundle"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

type entry struct {
	name     string
	body     string
	typeflag byte
}

func archive(t *testing.T, entries ...entry) []byte {
	t.Helper()
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	for _, e := range entries {
		h := &tar.Header{Name: e.name, Mode: 0o755, Size: int64(len(e.body)), Typeflag: e.typeflag}
		if e.typeflag == tar.TypeSymlink {
			h.Linkname, h.Size = "/etc/passwd", 0
		}
		if err := tw.WriteHeader(h); err != nil {
			t.Fatal(err)
		}
		_, _ = tw.Write([]byte(e.body))
	}
	_ = tw.Close()
	_ = gz.Close()
	return buf.Bytes()
}

func bundle(t *testing.T, marker string) []byte {
	return archive(t,
		entry{"ffmpeg/", "", tar.TypeDir},
		entry{"ffmpeg/bin/ffmpeg", "#!/bin/sh\necho " + marker + "\n", tar.TypeReg},
		entry{"ffmpeg/lib/libavcodec.so.62", "lib", tar.TypeReg},
	)
}

func TestExtract(t *testing.T) {
	dir := filepath.Join(t.TempDir(), "ffmpeg")
	if err := ffbundle.Extract(bundle(t, "v1"), dir); err != nil {
		t.Fatal(err)
	}
	st, err := os.Stat(filepath.Join(dir, "bin", "ffmpeg"))
	if err != nil || st.Mode().Perm()&0o100 == 0 {
		t.Fatalf("bin/ffmpeg not extracted as an executable: %v %v", st, err)
	}

	bad := map[string][]byte{
		"path traversal": archive(t, entry{"ffmpeg/../../evil", "x", tar.TypeReg}, entry{"ffmpeg/bin/ffmpeg", "x", tar.TypeReg}),
		"outside root":   archive(t, entry{"other/file", "x", tar.TypeReg}),
		"symlink":        archive(t, entry{"ffmpeg/bin/ffmpeg", "x", tar.TypeReg}, entry{"ffmpeg/lib/link", "", tar.TypeSymlink}),
		"no ffmpeg":      archive(t, entry{"ffmpeg/lib/x.so", "x", tar.TypeReg}),
		"not gzip":       []byte("nope"),
	}
	for name, a := range bad {
		if err := ffbundle.Extract(a, filepath.Join(t.TempDir(), "ffmpeg")); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
}

// release serves a signed fake release carrying bundle for this machine's architecture.
func release(t *testing.T, bundle []byte, tamper bool) (*updater.Client, *updater.Release) {
	t.Helper()
	pub, priv, err := ed25519.GenerateKey(rand.Reader)
	if err != nil {
		t.Fatal(err)
	}
	_, arch := updater.Platform()
	name := ffbundle.AssetName(arch)
	sum := sha256.Sum256(bundle)
	sums := fmt.Sprintf("%s  %s\n", hex.EncodeToString(sum[:]), name)
	sig := base64.StdEncoding.EncodeToString(ed25519.Sign(priv, []byte(sums)))
	served := bundle
	if tamper {
		served = append(append([]byte{}, bundle...), 0)
	}
	var srv *httptest.Server
	srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/repos/o/r/releases/tags/v1.2.3":
			_ = json.NewEncoder(w).Encode(map[string]any{"tag_name": "v1.2.3", "assets": []map[string]string{
				{"name": name, "browser_download_url": srv.URL + "/dl/bundle"},
				{"name": updater.SumsAsset, "browser_download_url": srv.URL + "/dl/sums"},
				{"name": updater.SigAsset, "browser_download_url": srv.URL + "/dl/sig"},
			}})
		case "/dl/bundle":
			_, _ = w.Write(served)
		case "/dl/sums":
			_, _ = w.Write([]byte(sums))
		case "/dl/sig":
			_, _ = w.Write([]byte(sig))
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	c, err := updater.New(srv.URL, "o/r", base64.StdEncoding.EncodeToString(pub))
	if err != nil {
		t.Fatal(err)
	}
	rel, err := c.Release(context.Background(), "1.2.3")
	if err != nil {
		t.Fatal(err)
	}
	return c, rel
}

func TestInstallReplaceAndActivate(t *testing.T) {
	ctx := context.Background()
	exe := filepath.Join(t.TempDir(), "alcove")
	dir := ffbundle.Dir(exe)

	c, rel := release(t, bundle(t, "v1"), false)
	if changed, err := ffbundle.Install(ctx, c, rel, dir); err != nil || !changed {
		t.Fatalf("first install: changed=%v err=%v", changed, err)
	}
	if changed, err := ffbundle.Install(ctx, c, rel, dir); err != nil || changed {
		t.Fatalf("same bundle again: changed=%v err=%v", changed, err)
	}

	c2, rel2 := release(t, bundle(t, "v2"), false)
	if changed, err := ffbundle.Install(ctx, c2, rel2, dir); err != nil || !changed {
		t.Fatalf("new bundle: changed=%v err=%v", changed, err)
	}
	b, _ := os.ReadFile(filepath.Join(dir, "bin", "ffmpeg"))
	if !strings.Contains(string(b), "v2") {
		t.Fatalf("bundle not replaced: %q", b)
	}
	if _, err := os.Stat(dir + ".old"); !os.IsNotExist(err) {
		t.Errorf("previous bundle left behind")
	}

	t.Setenv("PATH", "/usr/bin")
	if !ffbundle.Activate(exe) || !strings.HasPrefix(os.Getenv("PATH"), filepath.Join(dir, "bin")) {
		t.Fatalf("PATH = %q", os.Getenv("PATH"))
	}
}

func TestTamperedBundleIsRefused(t *testing.T) {
	c, rel := release(t, bundle(t, "v1"), true)
	dir := filepath.Join(t.TempDir(), "ffmpeg")
	if _, err := ffbundle.Install(context.Background(), c, rel, dir); err == nil || !strings.Contains(err.Error(), "checksum") {
		t.Fatalf("err = %v", err)
	}
	if _, err := os.Stat(dir); !os.IsNotExist(err) {
		t.Errorf("something was installed")
	}
}

func TestActivateWithoutBundle(t *testing.T) {
	t.Setenv("PATH", "/usr/bin")
	if ffbundle.Activate(filepath.Join(t.TempDir(), "alcove")) || os.Getenv("PATH") != "/usr/bin" {
		t.Fatal("activated a missing bundle")
	}
}

func TestRecent(t *testing.T) {
	cases := map[ffbundle.Version]bool{
		{}: false,
		{Found: true, Known: true, Major: 6, Minor: 1}: false,
		{Found: true, Known: true, Major: 7, Minor: 0}: false,
		{Found: true, Known: true, Major: 7, Minor: 1}: true,
		{Found: true, Known: true, Major: 8}:           true,
		{Found: true}:                                  true, // git build
	}
	for v, want := range cases {
		if v.Recent() != want {
			t.Errorf("%+v.Recent() = %v", v, !want)
		}
	}
}
