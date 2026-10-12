package media_test

import (
	"context"
	"image"
	_ "image/jpeg"
	"os"
	"path/filepath"
	"testing"

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
