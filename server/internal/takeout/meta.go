package takeout

import (
	"encoding/json"
	"errors"
	"io"
	"math"
	"strconv"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"
)

// maxJSON caps a sidecar or album metadata file. Real ones are a few hundred bytes.
const maxJSON = 1 << 20

// maxDescription matches media.description (migration 1791745200).
const maxDescription = 2000

// Meta is what Google Photos knows about one photo or video (its JSON sidecar).
type Meta struct {
	Taken       time.Time // photoTakenTime, UTC; zero when missing or absurd
	HasLocation bool
	Lat, Lon    float64
	Description string
	Favorite    bool
	Archived    bool
	Trashed     bool
}

type geo struct {
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

type stamp struct {
	Timestamp string `json:"timestamp"`
}

type sidecarJSON struct {
	Title          string `json:"title"`
	Description    string `json:"description"`
	PhotoTakenTime *stamp `json:"photoTakenTime"`
	GeoData        *geo   `json:"geoData"`
	GeoDataExif    *geo   `json:"geoDataExif"`
	Favorited      bool   `json:"favorited"`
	Archived       bool   `json:"archived"`
	Trashed        bool   `json:"trashed"`
	AlbumData      *struct {
		Title string `json:"title"`
	} `json:"albumData"`
}

var errJSONTooLarge = errors.New("json file too large")

// readJSON decodes at most maxJSON bytes.
func readJSON(r io.Reader) (sidecarJSON, error) {
	var out sidecarJSON
	b, err := io.ReadAll(io.LimitReader(r, maxJSON+1))
	if err != nil {
		return out, err
	}
	if len(b) > maxJSON {
		return out, errJSONTooLarge
	}
	err = json.Unmarshal(b, &out)
	return out, err
}

// isSidecar reports whether a JSON file describes a photo (not an album).
func (j sidecarJSON) isSidecar() bool { return j.PhotoTakenTime != nil }

// albumTitle is the title of an album's metadata.json (older exports nest it in albumData).
func (j sidecarJSON) albumTitle() string {
	t := j.Title
	if t == "" && j.AlbumData != nil {
		t = j.AlbumData.Title
	}
	return cleanText(t, 100)
}

// meta maps a sidecar to what Alcove keeps. now bounds dates (no photo is taken in the future).
func (j sidecarJSON) meta(now time.Time) Meta {
	m := Meta{
		Description: cleanText(j.Description, maxDescription),
		Favorite:    j.Favorited,
		Archived:    j.Archived,
		Trashed:     j.Trashed,
	}
	if j.PhotoTakenTime != nil {
		if sec, err := strconv.ParseInt(strings.TrimSpace(j.PhotoTakenTime.Timestamp), 10, 64); err == nil && sec > 0 {
			if t := time.Unix(sec, 0).UTC(); !t.After(now.Add(48 * time.Hour)) {
				m.Taken = t
			}
		}
	}
	// geoData is where Google shows the photo (maybe edited by the user); geoDataExif what the file said.
	for _, g := range []*geo{j.GeoData, j.GeoDataExif} {
		if validGeo(g) {
			m.HasLocation, m.Lat, m.Lon = true, g.Latitude, g.Longitude
			break
		}
	}
	return m
}

// validGeo: Google writes 0,0 when it has no position.
func validGeo(g *geo) bool {
	return g != nil && (g.Latitude != 0 || g.Longitude != 0) &&
		math.Abs(g.Latitude) <= 90 && math.Abs(g.Longitude) <= 180 &&
		!math.IsNaN(g.Latitude) && !math.IsNaN(g.Longitude)
}

// cleanText trims, drops control characters except newlines and cuts to max runes.
func cleanText(s string, max int) string {
	s = strings.Map(func(r rune) rune {
		if r == '\n' || r == '\t' {
			return r
		}
		if r < 0x20 || r == 0x7f || unicode.IsControl(r) || isBidiControl(r) {
			return -1
		}
		return r
	}, strings.ToValidUTF8(s, ""))
	s = strings.TrimSpace(s)
	if utf8.RuneCountInString(s) > max {
		s = string([]rune(s)[:max])
	}
	return s
}

// isBidiControl: embeddings, overrides and isolates can make text read differently than it is.
func isBidiControl(r rune) bool {
	return (r >= 0x202A && r <= 0x202E) || (r >= 0x2066 && r <= 0x2069) || r == 0x200E || r == 0x200F || r == 0x061C
}
