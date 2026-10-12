// Command mkphoto writes a test JPEG with EXIF metadata (fixtures for tests).
//
//	go run ./tools/mkphoto -out photo.jpg -w 640 -h 480 -taken 2025-06-01T12:00:00Z -make Apple -model "iPhone 16" -lat 45.76 -lon 4.83
package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
)

func main() {
	out := flag.String("out", "photo.jpg", "output file")
	w := flag.Int("w", 640, "width")
	h := flag.Int("h", 480, "height")
	taken := flag.String("taken", "", "date taken (RFC 3339), empty for none")
	mk := flag.String("make", "", "camera make")
	model := flag.String("model", "", "camera model")
	lat := flag.Float64("lat", 0, "latitude")
	lon := flag.Float64("lon", 0, "longitude")
	seed := flag.Uint64("seed", 0, "paint a textured scene (perceptual hashing tests)")
	flag.Parse()

	p := mediatest.Photo{Width: *w, Height: *h, Make: *mk, Model: *model, Lat: *lat, Lon: *lon, Seed: *seed}
	if *taken != "" {
		t, err := time.Parse(time.RFC3339, *taken)
		if err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		p.Taken = t
	}
	if err := os.WriteFile(*out, mediatest.JPEG(p), 0o644); err != nil { // #nosec G306 G703 -- test fixture
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
