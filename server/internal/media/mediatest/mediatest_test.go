package mediatest_test

import (
	"bytes"
	"math"
	"testing"
	"time"

	"github.com/evanoberholster/imagemeta"

	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
)

// The fixture must be readable by the EXIF library the server uses.
func TestFixtureRoundTrip(t *testing.T) {
	taken := time.Date(2024, 7, 14, 18, 30, 5, 0, time.UTC)
	b := mediatest.JPEG(mediatest.Photo{Width: 120, Height: 80, Taken: taken, Make: "Fujifilm", Model: "X100V", Lat: 48.8584, Lon: -2.2945})
	e, err := imagemeta.Decode(bytes.NewReader(b))
	if err != nil {
		t.Fatal(err)
	}
	if got := e.OriginalDate(); !got.Equal(taken) && got.Format("2006-01-02 15:04:05") != "2024-07-14 18:30:05" {
		t.Errorf("date = %v", got)
	}
	if e.IFD0.Make != "Fujifilm" || e.IFD0.Model != "X100V" {
		t.Errorf("camera = %q %q", e.IFD0.Make, e.IFD0.Model)
	}
	if math.Abs(e.GPS.Latitude()-48.8584) > 1e-4 || math.Abs(e.GPS.Longitude()+2.2945) > 1e-4 {
		t.Errorf("gps = %v %v", e.GPS.Latitude(), e.GPS.Longitude())
	}
}
