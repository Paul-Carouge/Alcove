package media_test

import (
	"bytes"
	"context"
	"image"
	_ "image/jpeg"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
)

func TestImageInfoSize(t *testing.T) {
	cases := []struct {
		name  string
		photo mediatest.Photo
		w, h  int
	}{
		{"plain", mediatest.Photo{Width: 64, Height: 32}, 64, 32},
		{"stale exif size", mediatest.Photo{Width: 64, Height: 32, ExifWidth: 8, ExifHeight: 8}, 64, 32},
		{"rotated 90°", mediatest.Photo{Width: 64, Height: 32, Orientation: 6}, 32, 64},
		{"upside down", mediatest.Photo{Width: 64, Height: 32, Orientation: 3}, 64, 32},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			path := filepath.Join(t.TempDir(), "p.jpg")
			if err := os.WriteFile(path, mediatest.JPEG(c.photo), 0o600); err != nil {
				t.Fatal(err)
			}
			info, err := media.ImageInfo(path)
			if err != nil {
				t.Fatal(err)
			}
			if info.Width != c.w || info.Height != c.h {
				t.Fatalf("size = %dx%d, want %dx%d", info.Width, info.Height, c.w, c.h)
			}
		})
	}
}

func TestDerivativesFollowExifOrientation(t *testing.T) {
	if !media.HaveFFmpeg() {
		t.Skip("ffmpeg not installed")
	}
	dir := t.TempDir()
	src := filepath.Join(dir, "p.jpg")
	// Stored landscape, displayed portrait (rotate 90° clockwise).
	if err := os.WriteFile(src, mediatest.JPEG(mediatest.Photo{Width: 640, Height: 320, Orientation: 6}), 0o600); err != nil {
		t.Fatal(err)
	}
	thumb, preview := filepath.Join(dir, "t.jpg"), filepath.Join(dir, "p2.jpg")
	if err := media.Derivatives(context.Background(), src, thumb, preview, false, 0); err != nil {
		t.Fatal(err)
	}
	for _, p := range []string{thumb, preview} {
		f, err := os.Open(p)
		if err != nil {
			t.Fatal(err)
		}
		cfg, _, err := image.DecodeConfig(f)
		_ = f.Close()
		if err != nil {
			t.Fatal(err)
		}
		if cfg.Width >= cfg.Height {
			t.Errorf("%s is %dx%d, want portrait", filepath.Base(p), cfg.Width, cfg.Height)
		}
	}
}

// Some phones put a HEIC's EXIF where the metadata decoder does not look; the TIFF block is found in
// the file instead.
func TestHEICMetadataFallback(t *testing.T) {
	jpg := mediatest.JPEG(mediatest.Photo{Width: 8, Height: 8, Make: "OPPO", Model: "Find X9 Pro",
		Taken: time.Date(2026, 10, 11, 20, 48, 2, 0, time.UTC), Lat: 45.76, Lon: 4.83})
	at := bytes.Index(jpg, []byte("II\x2a\x00")) // mediatest writes little-endian TIFF
	if at < 0 {
		t.Fatal("no TIFF header in the generated EXIF")
	}
	tiff := jpg[at:]
	fake := append([]byte("\x00\x00\x00\x18ftypheic\x00\x00\x00\x00mif1heic"), make([]byte, 64)...)
	fake = append(fake, tiff...)
	path := filepath.Join(t.TempDir(), "phone.heic")
	if err := os.WriteFile(path, fake, 0o600); err != nil {
		t.Fatal(err)
	}
	info, err := media.ImageInfo(path)
	if err != nil {
		t.Fatal(err)
	}
	if info.Model != "Find X9 Pro" || info.Taken.Year() != 2026 || !info.HasLocation {
		t.Errorf("info = %+v", info)
	}
}
