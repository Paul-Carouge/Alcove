package takeout

import (
	"testing"
	"time"
)

func stems(names ...string) map[string]bool {
	m := map[string]bool{}
	for _, n := range names {
		m[stemOf(n)] = true
	}
	return m
}

func TestFindSidecar(t *testing.T) {
	long := "Screenshot_20190101-123456_Some Very Long App Name.jpg" // 54 characters
	nav := "Screenshot_20231105-142312_Google Maps Navigation.jpg"
	tests := []struct {
		name, media string
		jsons       []string
		want        string // "" = no match
	}{
		{"plain", "photo.jpg", []string{"photo.jpg.json"}, "photo.jpg"},
		{"supplemental", "photo.jpg", []string{"photo.jpg.supplemental-metadata.json"}, "photo.jpg.supplemental-metadata"},
		{"supplemental cut", "IMG_20190704_101112.jpg", []string{"IMG_20190704_101112.jpg.supplemental-metad.json"}, "IMG_20190704_101112.jpg.supplemental-metad"},
		{"suppl", "IMG_20190704_101112.jpg", []string{"IMG_20190704_101112.jpg.suppl.json"}, "IMG_20190704_101112.jpg.suppl"},
		{"prefers the longest", "a.jpg", []string{"a.jpg.json", "a.jpg.supplemental-metadata.json"}, "a.jpg.supplemental-metadata"},
		{"name cut at 46", long, []string{long[:46] + ".json"}, long[:46]},
		{"short cut refused", "photo-from-holidays.jpg", []string{"photo-from.json"}, ""},
		{"counter", "photo(1).jpg", []string{"photo.jpg.json", "photo.jpg(1).json"}, "photo.jpg(1)"},
		{"counter supplemental", "photo(2).jpg", []string{"photo.jpg.supplemental-metadata(2).json"}, "photo.jpg.supplemental-metadata(2)"},
		{"counter without its json", "photo(1).jpg", []string{"photo.jpg.json"}, ""},
		{"literal parentheses", "photo(1).jpg", []string{"photo(1).jpg.json"}, "photo(1).jpg"},
		{"edited", "photo-edited.jpg", []string{"photo.jpg.json"}, "photo.jpg"},
		{"edited french", "photo-modifié.jpg", []string{"photo.jpg.supplemental-metadata.json"}, "photo.jpg.supplemental-metadata"},
		{"edited french NFD", "photo-modifié.jpg", []string{"photo.jpg.json"}, "photo.jpg"},
		{"edited german", "photo-bearbeitet.JPG", []string{"photo.JPG.json"}, "photo.JPG"},
		{"no json", "lonely.jpg", []string{"other.jpg.json"}, ""},
		{"no prefix confusion", "IMG_1.jpg", []string{"IMG_10.jpg.json"}, ""},
		// A long "(1)" copy takes its own cut JSON, not its original's.
		{"long counter copy", "Screenshot_20231105-142312_Google Maps Navigation(1).jpg",
			[]string{nav[:46] + ".json", nav[:46] + "(1).json"}, nav[:46] + "(1)"},
		{"long original", nav, []string{nav[:46] + ".json", nav[:46] + "(1).json"}, nav[:46]},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, _, ok := findSidecar(tt.media, stems(tt.jsons...), nil)
			if got != tt.want || ok != (tt.want != "") {
				t.Errorf("findSidecar(%q) = %q, %v; want %q", tt.media, got, ok, tt.want)
			}
		})
	}
}

func TestLibraryYearAndAlbumMeta(t *testing.T) {
	for dir, want := range map[string]int{
		"Takeout/Google Photos/Photos from 2019": 2019,
		"Takeout/Google Photos/Photos de 2008":   2008,
		"Takeout/Google Fotos/Fotos von 2021":    2021,
		"Takeout/Google Photos/Trip 2019":        0,
		"Takeout/Google Photos/Photos from 1850": 0,
	} {
		if got := libraryYear(dir); got != want {
			t.Errorf("libraryYear(%q) = %d, want %d", dir, got, want)
		}
	}
	for name, want := range map[string]bool{
		"metadata.json": true, "métadonnées.json": true, "métadonnées.json": true,
		"metadata(1).json": true, "metadata.jpg.json": false, "photo.json": false,
	} {
		if got := albumMetaName.MatchString(name); got != want {
			t.Errorf("albumMetaName(%q) = %v", name, got)
		}
	}
}

func TestMetaMapping(t *testing.T) {
	now := time.Date(2026, 10, 1, 0, 0, 0, 0, time.UTC)
	parse := func(s string) Meta {
		j, err := readJSON(stringsReader(s))
		if err != nil {
			t.Fatal(err)
		}
		return j.meta(now)
	}
	m := parse(`{"title":"a.jpg","description":" Plage \u0007 ","photoTakenTime":{"timestamp":"1373803200"},
		"geoData":{"latitude":0,"longitude":0},"geoDataExif":{"latitude":43.29,"longitude":5.37},
		"favorited":true,"archived":true}`)
	if !m.Taken.Equal(time.Date(2013, 7, 14, 12, 0, 0, 0, time.UTC)) {
		t.Errorf("taken = %v", m.Taken)
	}
	if !m.HasLocation || m.Lat != 43.29 || m.Lon != 5.37 {
		t.Errorf("location = %v %v %v (0,0 must be ignored, geoDataExif used)", m.HasLocation, m.Lat, m.Lon)
	}
	if m.Description != "Plage" || !m.Favorite || !m.Archived || m.Trashed {
		t.Errorf("meta = %+v", m)
	}
	if m := parse(`{"photoTakenTime":{"timestamp":"4102444800"},"trashed":true,"geoData":{"latitude":91,"longitude":0}}`); !m.Taken.IsZero() || m.HasLocation || !m.Trashed {
		t.Errorf("future date / invalid position / trashed: %+v", m)
	}
	if m := parse(`{"photoTakenTime":{"timestamp":"0"},"geoData":{"latitude":48.85,"longitude":2.35}}`); !m.Taken.IsZero() || !m.HasLocation || m.Lat != 48.85 {
		t.Errorf("zero date / geoData: %+v", m)
	}
	if _, err := readJSON(stringsReader(`{"title":"` + string(make([]byte, maxJSON)) + `"}`)); err == nil {
		t.Error("oversized JSON accepted")
	}
	j, _ := readJSON(stringsReader(`{"title":"Summer trip","description":""}`))
	if j.isSidecar() || j.albumTitle() != "Summer trip" {
		t.Errorf("album metadata: %+v", j)
	}
	j, _ = readJSON(stringsReader(`{"albumData":{"title":"Old format"}}`))
	if j.albumTitle() != "Old format" {
		t.Errorf("albumData title = %q", j.albumTitle())
	}
}

func TestNodeName(t *testing.T) {
	if got := nodeName("ok.jpg"); got != "ok.jpg" {
		t.Error(got)
	}
	if got := nodeName("a\x01b.jpg"); got != "a_b.jpg" {
		t.Error(got)
	}
	if got := nodeName("..."); got != "photo" {
		t.Error(got)
	}
}
