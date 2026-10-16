package takeout

import (
	"bytes"
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"slices"
	"testing"
	"time"
)

func TestCleanEntryPath(t *testing.T) {
	for name, ok := range map[string]bool{
		"Takeout/Google Photos/a.jpg": true,
		"../evil.jpg":                 false,
		"Takeout/../../etc/passwd":    false,
		"/etc/passwd":                 false,
		"a\\b.jpg":                    false,
		"a/./b.jpg":                   false,
		"a//b.jpg":                    false,
		"bad\x00.jpg":                 false,
		"bad\nname.jpg":               false,
		string([]byte{0xff, 'a'}):     false,
		string(make([]byte, 2000)):    false,
	} {
		if _, got := cleanEntryPath(name); got != ok {
			t.Errorf("cleanEntryPath(%q) = %v, want %v", name, got, ok)
		}
	}
}

func openTest(t *testing.T, dir string, names ...string) *archives {
	t.Helper()
	root, err := os.OpenRoot(dir)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = root.Close() }()
	a, err := openSources(root, names)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(a.Close)
	return a
}

func TestZipSafety(t *testing.T) {
	dir := t.TempDir()
	bomb := bytes.Repeat([]byte{0}, ratioMinBytes+1) // compresses ~1000:1
	writeZip(t, filepath.Join(dir, "t.zip"),
		zipFile{name: "Takeout/Google Photos/Photos from 2020/ok.jpg", data: []byte("jpeg"), store: true},
		zipFile{name: "../escape.jpg", data: []byte("x")},
		zipFile{name: "Takeout/Google Photos/Photos from 2020/bomb.jpg", data: bomb},
	)
	a := openTest(t, dir, "t.zip")
	entries, err := a.entries(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	var paths []string
	for _, e := range entries {
		paths = append(paths, e.path)
	}
	if slices.Contains(paths, "../escape.jpg") || len(entries) != 2 {
		t.Fatalf("entries = %v", paths)
	}
	var buf bytes.Buffer
	if n, err := a.copyEntry(context.Background(), entries[0], &buf); err != nil || n != 4 {
		t.Errorf("copy ok.jpg: %d %v", n, err)
	}
	if _, err := a.copyEntry(context.Background(), entries[1], io.Discard); !errors.Is(err, errSuspicious) {
		t.Errorf("bomb: %v, want errSuspicious", err)
	}
	// A directory that lies about the size is cut and refused.
	lying := entries[0]
	lying.size = 2
	if _, err := a.copyEntry(context.Background(), lying, io.Discard); err == nil {
		t.Error("size mismatch accepted")
	}

	old := maxEntriesPerArchive
	maxEntriesPerArchive = 1
	defer func() { maxEntriesPerArchive = old }()
	if _, err := a.entries(context.Background()); !errors.Is(err, errTooManyEntries) {
		t.Errorf("entry limit: %v", err)
	}
}

func TestFolderConfinement(t *testing.T) {
	dir := t.TempDir()
	outside := t.TempDir()
	if err := os.WriteFile(filepath.Join(outside, "secret.jpg"), []byte("secret"), 0o600); err != nil {
		t.Fatal(err)
	}
	album := filepath.Join(dir, "Takeout", "Google Photos", "Photos from 2021")
	if err := os.MkdirAll(album, 0o750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(album, "a.jpg"), []byte("a"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(filepath.Join(outside, "secret.jpg"), filepath.Join(album, "link.jpg")); err != nil {
		t.Fatal(err)
	}
	if err := os.Symlink(outside, filepath.Join(album, "linkdir")); err != nil {
		t.Fatal(err)
	}
	a := openTest(t, dir, "Takeout")
	entries, err := a.entries(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if len(entries) != 1 || entries[0].name() != "a.jpg" {
		t.Fatalf("entries = %+v (symbolic links must be ignored)", entries)
	}
	// Even a forged entry cannot read outside the folder.
	if _, err := a.open(entry{src: 0, path: "Google Photos/Photos from 2021/link.jpg"}); err == nil {
		t.Error("symbolic link escaping the folder opened")
	}

	root, _ := os.OpenRoot(dir)
	defer func() { _ = root.Close() }()
	for _, bad := range []string{"../" + filepath.Base(outside), "/etc"} {
		if a, err := openSources(root, []string{bad}); err == nil {
			a.Close()
			t.Errorf("openSources(%q) escaped the import folder", bad)
		}
	}
}

func TestBuildPlan(t *testing.T) {
	dir := t.TempDir()
	lib := "Takeout/Google Photos/Photos from 2019/"
	trip := "Takeout/Google Photos/Summer trip/"
	writeZip(t, filepath.Join(dir, "takeout-001.zip"),
		zipFile{name: lib + "IMG_1.HEIC", data: []byte("heic"), store: true},
		zipFile{name: lib + "IMG_1.MP4", data: []byte("mp4"), store: true},
		zipFile{name: lib + "photo(1).jpg", data: []byte("p1"), store: true},
		zipFile{name: lib + "photo-edited.jpg", data: []byte("pe"), store: true},
		zipFile{name: lib + "nojson.png", data: []byte("png"), store: true},
		zipFile{name: trip + "beach.jpg", data: []byte("beach"), store: true},
		named(trip+"metadata.json", js(`{"title":"Summer trip"}`)),
		named("Takeout/Google Photos/Archive/kept.jpg", zipFile{data: []byte("k")}),
		named("Takeout/archive_browser.html", zipFile{data: []byte("<html>")}),
	)
	// The JSON of a photo may sit in another archive of the same export.
	writeZip(t, filepath.Join(dir, "takeout-002.zip"),
		named(lib+"IMG_1.HEIC.supplemental-metadata.json", js(`{"photoTakenTime":{"timestamp":"1561939200"},"favorited":true}`)),
		named(lib+"photo.jpg(1).json", js(`{"photoTakenTime":{"timestamp":"1546300800"}}`)),
		named(lib+"photo.jpg.json", js(`{"photoTakenTime":{"timestamp":"1546387200"}}`)),
		named(trip+"beach.jpg.json", js(`{"photoTakenTime":{"timestamp":"1562000000"},"trashed":true}`)),
	)
	a := openTest(t, dir, "takeout-001.zip", "takeout-002.zip")
	entries, err := a.entries(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	p, err := buildPlan(context.Background(), entries, func(e entry) (sidecarJSON, error) {
		rc, err := a.open(e)
		if err != nil {
			return sidecarJSON{}, err
		}
		defer func() { _ = rc.Close() }()
		return readJSON(rc)
	}, time.Now())
	if err != nil {
		t.Fatal(err)
	}

	byName := map[string]item{}
	var order []string
	for _, it := range p.items {
		byName[it.name()] = it
		order = append(order, it.name())
	}
	if len(p.items) != 7 || p.albums != 1 {
		t.Fatalf("items = %v, albums = %d", order, p.albums)
	}
	if order[len(order)-1] != "beach.jpg" {
		t.Errorf("album items must come after the library: %v", order)
	}
	if it := byName["IMG_1.HEIC"]; !it.hasMeta || !it.meta.Favorite || it.meta.Taken.Year() != 2019 || it.year != 2019 {
		t.Errorf("HEIC: %+v", it)
	}
	if it := byName["IMG_1.MP4"]; !it.live || !it.meta.Favorite {
		t.Errorf("Live Photo video must share the image's metadata: %+v", it)
	}
	if it := byName["photo(1).jpg"]; it.meta.Taken.Unix() != 1546300800 {
		t.Errorf("counter: %+v", it.meta)
	}
	if it := byName["photo-edited.jpg"]; !it.edited || it.meta.Taken.Unix() != 1546387200 {
		t.Errorf("edited: %+v", it)
	}
	if it := byName["nojson.png"]; it.hasMeta {
		t.Errorf("no JSON: %+v", it)
	}
	if it := byName["beach.jpg"]; it.album != "Summer trip" || !it.meta.Trashed {
		t.Errorf("album item: %+v", it)
	}
	if it := byName["kept.jpg"]; it.album != "" {
		t.Errorf("a folder without album metadata is library: %+v", it)
	}
}
