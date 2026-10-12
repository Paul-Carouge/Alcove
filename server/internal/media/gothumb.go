package media

import (
	"errors"
	"fmt"
	"image"
	"image/jpeg"
	"os"

	"golang.org/x/image/draw"
)

// maxGoPixels bounds images decoded in memory by the Go thumbnailer (~400 MB as RGBA).
const maxGoPixels = 100_000_000

// GoDerivatives renders the thumbnail (360 px high) and preview (1600 px box) of a JPEG, PNG, GIF
// or WebP without ffmpeg, applying the EXIF orientation. Slower than ffmpeg, but always available.
func GoDerivatives(src, thumb, preview string, orientation int) error {
	f, err := os.Open(src) // #nosec G304 -- temp copy made by the worker
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()
	cfg, _, err := image.DecodeConfig(f)
	if err != nil {
		return fmt.Errorf("decode: %w", err)
	}
	if cfg.Width*cfg.Height > maxGoPixels {
		return errors.New("image too large to thumbnail without ffmpeg")
	}
	if _, err := f.Seek(0, 0); err != nil {
		return err
	}
	img, _, err := image.Decode(f)
	if err != nil {
		return fmt.Errorf("decode: %w", err)
	}
	img = orient(img, orientation)

	b := img.Bounds()
	pw, ph := fit(b.Dx(), b.Dy(), 1600, 1600)
	big := image.NewRGBA(image.Rect(0, 0, pw, ph))
	draw.ApproxBiLinear.Scale(big, big.Bounds(), img, b, draw.Src, nil)
	if err := writeJPEG(preview, big); err != nil {
		return err
	}
	tw, th := max(1, b.Dx()*360/max(1, b.Dy())), 360
	if b.Dy() < 360 {
		tw, th = b.Dx(), b.Dy()
	}
	small := image.NewRGBA(image.Rect(0, 0, tw, th))
	draw.CatmullRom.Scale(small, small.Bounds(), big, big.Bounds(), draw.Src, nil)
	return writeJPEG(thumb, small)
}

// fit scales w×h down to fit a box, never up.
func fit(w, h, bw, bh int) (int, int) {
	if w <= bw && h <= bh {
		return w, h
	}
	if w*bh > h*bw {
		return bw, max(1, h*bw/w)
	}
	return max(1, w*bh/h), bh
}

func writeJPEG(path string, img image.Image) error {
	out, err := os.Create(path) // #nosec G304 -- inside the worker's temp dir
	if err != nil {
		return err
	}
	if err := jpeg.Encode(out, img, &jpeg.Options{Quality: 82}); err != nil {
		_ = out.Close()
		return err
	}
	return out.Close()
}

// orient applies an EXIF orientation so the image is upright.
func orient(src image.Image, o int) image.Image {
	if o < 2 || o > 8 {
		return src
	}
	b := src.Bounds()
	w, h := b.Dx(), b.Dy()
	swap := o >= 5
	dw, dh := w, h
	if swap {
		dw, dh = h, w
	}
	dst := image.NewRGBA(image.Rect(0, 0, dw, dh))
	for y := range h {
		for x := range w {
			var dx, dy int
			switch o {
			case 2: // mirror horizontal
				dx, dy = w-1-x, y
			case 3: // rotate 180
				dx, dy = w-1-x, h-1-y
			case 4: // mirror vertical
				dx, dy = x, h-1-y
			case 5: // transpose
				dx, dy = y, x
			case 6: // rotate 90 clockwise
				dx, dy = h-1-y, x
			case 7: // transverse
				dx, dy = h-1-y, w-1-x
			case 8: // rotate 90 counter-clockwise
				dx, dy = y, w-1-x
			}
			dst.Set(dx, dy, src.At(b.Min.X+x, b.Min.Y+y))
		}
	}
	return dst
}
