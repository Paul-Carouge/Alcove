package takeout

import (
	"archive/zip"
	"bytes"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func stringsReader(s string) io.Reader { return strings.NewReader(s) }

// zipFile is one entry of a test archive; store: written uncompressed (photos are).
type zipFile struct {
	name  string
	data  []byte
	store bool
}

// writeZip builds a small Takeout-like archive at path.
func writeZip(t *testing.T, path string, files ...zipFile) {
	t.Helper()
	var buf bytes.Buffer
	zw := zip.NewWriter(&buf)
	for _, f := range files {
		method := zip.Deflate
		if f.store {
			method = zip.Store
		}
		w, err := zw.CreateHeader(&zip.FileHeader{Name: f.name, Method: method})
		if err != nil {
			t.Fatal(err)
		}
		if _, err := w.Write(f.data); err != nil {
			t.Fatal(err)
		}
	}
	if err := zw.Close(); err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(filepath.Dir(path), 0o750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(path, buf.Bytes(), 0o600); err != nil {
		t.Fatal(err)
	}
}

func js(s string) zipFile                  { return zipFile{data: []byte(s)} }
func named(name string, f zipFile) zipFile { f.name = name; return f }
