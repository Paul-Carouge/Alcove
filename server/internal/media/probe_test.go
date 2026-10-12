package media_test

import (
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
