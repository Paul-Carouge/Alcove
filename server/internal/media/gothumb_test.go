package media_test

import (
	"image"
	"image/color"
	"image/png"
	"os"
	"path/filepath"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
)

func size(t *testing.T, path string) (int, int) {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = f.Close() }()
	cfg, _, err := image.DecodeConfig(f)
	if err != nil {
		t.Fatal(err)
	}
	return cfg.Width, cfg.Height
}

func TestGoDerivatives(t *testing.T) {
	cases := []struct {
		name                 string
		w, h, orientation    int
		thumbW, thumbH, preW int
	}{
		{"landscape", 2000, 1000, 1, 720, 360, 1600},
		{"rotated 90°", 2000, 1000, 6, 180, 360, 800},
		{"rotated 270°", 2000, 1000, 8, 180, 360, 800},
		{"upside down", 2000, 1000, 3, 720, 360, 1600},
		{"small", 300, 200, 0, 300, 200, 300},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			dir := t.TempDir()
			src := filepath.Join(dir, "src.jpg")
			if err := os.WriteFile(src, mediatest.JPEG(mediatest.Photo{Width: c.w, Height: c.h}), 0o600); err != nil {
				t.Fatal(err)
			}
			thumb, preview := filepath.Join(dir, "t.jpg"), filepath.Join(dir, "p.jpg")
			if err := media.GoDerivatives(src, thumb, preview, c.orientation); err != nil {
				t.Fatal(err)
			}
			if w, h := size(t, thumb); w != c.thumbW || h != c.thumbH {
				t.Errorf("thumb %dx%d, want %dx%d", w, h, c.thumbW, c.thumbH)
			}
			if w, _ := size(t, preview); w != c.preW {
				t.Errorf("preview width %d, want %d", w, c.preW)
			}
		})
	}
}

func TestGoDerivativesOrientationPixels(t *testing.T) {
	// 40×20 PNG: red left half, blue right half. Rotated 90° clockwise, red ends up on top.
	img := image.NewRGBA(image.Rect(0, 0, 40, 20))
	for y := range 20 {
		for x := range 40 {
			c := color.RGBA{255, 0, 0, 255}
			if x >= 20 {
				c = color.RGBA{0, 0, 255, 255}
			}
			img.Set(x, y, c)
		}
	}
	dir := t.TempDir()
	src := filepath.Join(dir, "src.png")
	f, _ := os.Create(src)
	_ = png.Encode(f, img)
	_ = f.Close()
	thumb, preview := filepath.Join(dir, "t.jpg"), filepath.Join(dir, "p.jpg")
	if err := media.GoDerivatives(src, thumb, preview, 6); err != nil {
		t.Fatal(err)
	}
	pf, _ := os.Open(preview)
	defer func() { _ = pf.Close() }()
	out, _, err := image.Decode(pf)
	if err != nil {
		t.Fatal(err)
	}
	if b := out.Bounds(); b.Dx() != 20 || b.Dy() != 40 {
		t.Fatalf("preview %v, want 20x40", b)
	}
	if r, _, bl, _ := out.At(10, 5).RGBA(); r < bl {
		t.Errorf("top is not red after rotation")
	}
	if r, _, bl, _ := out.At(10, 35).RGBA(); r > bl {
		t.Errorf("bottom is not blue after rotation")
	}
}

func TestGoDerivativesRejectsGarbage(t *testing.T) {
	dir := t.TempDir()
	src := filepath.Join(dir, "x.jpg")
	_ = os.WriteFile(src, []byte("not an image"), 0o600)
	if err := media.GoDerivatives(src, filepath.Join(dir, "t.jpg"), filepath.Join(dir, "p.jpg"), 0); err == nil {
		t.Fatal("garbage accepted")
	}
}
