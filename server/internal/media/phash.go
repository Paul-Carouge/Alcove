package media

import (
	"fmt"
	"image"
	"io"
	"os"

	"golang.org/x/image/draw"
)

// DHash is a perceptual fingerprint: a 64-bit difference hash of the brightness (visually similar
// images, resized, recompressed or burst shots, differ in only a few bits) followed by the average colour,
// as 16 + 6 hex digits. Computed from the generated thumbnail.
func DHash(r io.Reader) (string, error) {
	img, _, err := image.Decode(r)
	if err != nil {
		return "", err
	}
	small := image.NewGray(image.Rect(0, 0, 9, 8))
	draw.BiLinear.Scale(small, small.Bounds(), img, img.Bounds(), draw.Src, nil)
	tiny := image.NewRGBA(image.Rect(0, 0, 1, 1))
	draw.ApproxBiLinear.Scale(tiny, tiny.Bounds(), img, img.Bounds(), draw.Src, nil)
	avg := tiny.RGBAAt(0, 0)
	var h uint64
	for y := range 8 {
		for x := range 8 {
			h <<= 1
			if small.GrayAt(x, y).Y < small.GrayAt(x+1, y).Y {
				h |= 1
			}
		}
	}
	return fmt.Sprintf("%016x%02x%02x%02x", h, avg.R, avg.G, avg.B), nil
}

func dhashFile(path string) (string, error) {
	f, err := os.Open(path) // #nosec G304 -- inside the worker's temp dir
	if err != nil {
		return "", err
	}
	defer func() { _ = f.Close() }()
	return DHash(f)
}
