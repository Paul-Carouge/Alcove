package takeout

import (
	"cmp"
	"context"
	"errors"
	"path"
	"slices"
	"strings"
	"time"
)

// item is one photo or video to import.
type item struct {
	entry
	meta    Meta
	hasMeta bool
	album   string // album title; "" for the library
	year    int    // year of the library folder it came from ("Photos from 2019"), 0 otherwise
	edited  bool   // an edited copy ("-edited"), imported next to its original
	live    bool   // the video half of a Live Photo, sharing the image's metadata
}

// plan pairs media with their sidecars and album folders. Library items come first so an album's copy
// of a photo finds the library copy already imported (one file, added to the album).
type plan struct {
	items  []item
	albums int // album folders found
}

// readJSONFn reads one JSON entry (injected for tests).
type readJSONFn func(entry) (sidecarJSON, error)

// buildPlan groups entries by folder (a photo and its JSON may sit in different archives of the same
// export, in the same folder path), then matches each media file with its sidecar.
func buildPlan(ctx context.Context, entries []entry, read readJSONFn, now time.Time) (plan, error) {
	type folder struct {
		media []entry
		jsons map[string]Meta // by stem
		album string
	}
	folders := map[string]*folder{}
	get := func(dir string) *folder {
		f := folders[dir]
		if f == nil {
			f = &folder{jsons: map[string]Meta{}}
			folders[dir] = f
		}
		return f
	}
	for i, e := range entries {
		if i%1024 == 0 && ctx.Err() != nil {
			return plan{}, ctx.Err()
		}
		name := e.name()
		switch {
		case isMedia(name):
			get(e.dir()).media = append(get(e.dir()).media, e)
		case strings.EqualFold(path.Ext(name), ".json") && e.size <= maxJSON:
			j, err := read(e)
			if errors.Is(err, errBudget) {
				return plan{}, err
			}
			if err != nil {
				continue
			}
			f := get(e.dir())
			if albumMetaName.MatchString(name) && !j.isSidecar() {
				if t := j.albumTitle(); t != "" && f.album == "" {
					f.album = t
				}
				continue
			}
			f.jsons[stemOf(name)] = j.meta(now)
		}
	}

	var p plan
	dirs := slices.Sorted(func(yield func(string) bool) {
		for d := range folders {
			if !yield(d) {
				return
			}
		}
	})
	var library, albums []item
	for _, dir := range dirs {
		f := folders[dir]
		year := libraryYear(dir)
		album := ""
		if year == 0 {
			album = f.album // a folder without album metadata ("Archive", "Trash"…) is library
		}
		if album != "" && len(f.media) > 0 {
			p.albums++
		}
		stems := make(map[string]bool, len(f.jsons))
		for s := range f.jsons {
			stems[s] = true
		}
		slices.SortFunc(f.media, func(a, b entry) int {
			return cmp.Or(cmp.Compare(a.name(), b.name()), cmp.Compare(a.src, b.src))
		})
		images := map[string]Meta{} // Live Photo pairing: image stem → its metadata
		taken := map[string]bool{}  // cut stems already matched: one file each
		var pending []item
		for _, e := range f.media {
			it := item{entry: e, album: album, year: year}
			_, it.edited = unedited(e.name())
			if s, cut, ok := findSidecar(e.name(), stems, taken); ok {
				if cut && !it.edited {
					taken[s] = true
				}
				it.meta, it.hasMeta = f.jsons[s], true
				if !videoExts[strings.ToLower(path.Ext(e.name()))] {
					images[liveStem(e.name())] = it.meta
				}
			}
			pending = append(pending, it)
		}
		for i := range pending {
			it := &pending[i]
			if it.hasMeta || !videoExts[strings.ToLower(path.Ext(it.name()))] {
				continue
			}
			if m, ok := images[liveStem(it.name())]; ok {
				it.meta, it.hasMeta, it.live = m, true, true
			}
		}
		if album != "" {
			albums = append(albums, pending...)
		} else {
			library = append(library, pending...)
		}
	}
	p.items = append(library, albums...)
	return p, ctx.Err()
}
