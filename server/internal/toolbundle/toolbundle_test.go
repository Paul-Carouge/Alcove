package toolbundle_test

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"os"
	"path/filepath"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/toolbundle"
)

func archive(t *testing.T, files map[string]string) []byte {
	t.Helper()
	var buf bytes.Buffer
	gz := gzip.NewWriter(&buf)
	tw := tar.NewWriter(gz)
	for name, body := range files {
		if err := tw.WriteHeader(&tar.Header{Name: name, Mode: 0o755, Size: int64(len(body)), Typeflag: tar.TypeReg}); err != nil {
			t.Fatal(err)
		}
		_, _ = tw.Write([]byte(body))
	}
	_ = tw.Close()
	_ = gz.Close()
	return buf.Bytes()
}

func TestExtractChecksNameAndProbe(t *testing.T) {
	b := toolbundle.Bundle{Name: "ocr", Probe: "bin/tesseract"}
	dir := filepath.Join(t.TempDir(), "ocr")
	if err := b.Extract(archive(t, map[string]string{"ocr/bin/tesseract": "#!/bin/sh", "ocr/share/tessdata/fra.traineddata": "x"}), dir); err != nil {
		t.Fatal(err)
	}
	if _, err := os.Stat(filepath.Join(dir, "share/tessdata/fra.traineddata")); err != nil {
		t.Error(err)
	}
	for name, files := range map[string]map[string]string{
		"no probe":      {"ocr/bin/other": "x"},
		"other bundle":  {"ffmpeg/bin/tesseract": "x"},
		"path escaping": {"ocr/../evil": "x", "ocr/bin/tesseract": "x"},
	} {
		if err := b.Extract(archive(t, files), filepath.Join(t.TempDir(), "x")); err == nil {
			t.Errorf("%s: accepted", name)
		}
	}
	if got := b.AssetName("arm64"); got != "ocr_linux_arm64.tar.gz" {
		t.Errorf("asset = %s", got)
	}
}
