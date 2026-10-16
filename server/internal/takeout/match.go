package takeout

import (
	"path"
	"regexp"
	"strconv"
	"strings"
	"unicode/utf8"
)

// mediaExts are the photo and video types Google Photos stores. Everything else in an archive (HTML
// pages, JSON) is not imported.
var mediaExts = map[string]bool{
	".jpg": true, ".jpeg": true, ".png": true, ".gif": true, ".webp": true, ".heic": true, ".heif": true,
	".avif": true, ".bmp": true, ".tif": true, ".tiff": true, ".dng": true, ".cr2": true, ".cr3": true,
	".nef": true, ".arw": true, ".orf": true, ".rw2": true, ".raf": true,
	".mp4": true, ".mov": true, ".m4v": true, ".3gp": true, ".avi": true, ".mkv": true, ".webm": true,
	".mts": true, ".m2ts": true, ".mpg": true, ".mpeg": true, ".wmv": true,
}

var videoExts = map[string]bool{".mp4": true, ".mov": true, ".m4v": true, ".3gp": true}

func isMedia(name string) bool { return mediaExts[strings.ToLower(path.Ext(name))] }

// yearFolder matches the library folders ("Photos from 2019"), in the languages Takeout uses.
var yearFolder = regexp.MustCompile(`^(?:Photos from|Photos de|Fotos von|Fotos de|Foto dal|Foto del|Foto's van|Fotos från|Zdjęcia z) ((?:19|20)\d\d)$`)

// libraryYear returns the year of a library folder, or 0 for any other folder.
func libraryYear(dir string) int {
	if m := yearFolder.FindStringSubmatch(path.Base(dir)); m != nil {
		y, _ := strconv.Atoi(m[1])
		return y
	}
	return 0
}

// albumMetaName matches an album's metadata file (its name is localized).
var albumMetaName = regexp.MustCompile(`(?i)^(?:metadata|métadonnées|me\x{0301}tadonne\x{0301}es|metadaten|metadatos|metadati|metadados|metagegevens)(?:\(\d+\))?\.json$`)

// editedSuffixes mark the copy Google saves when a photo is edited ("photo-edited.jpg"), localized.
// "modifié" appears both composed and decomposed (NFD) in archives made on macOS.
var editedSuffixes = []string{
	"-edited", "-modifié", "-modifie\u0301", "-bearbeitet", "-editado",
	"-modificato", //nolint:misspell // Italian
	"-bewerkt", "-redigerad", "-edytowane",
}

// unedited returns the original's name of an edited copy ("photo-edited.jpg" → "photo.jpg").
func unedited(name string) (string, bool) {
	ext := path.Ext(name)
	stem := strings.TrimSuffix(name, ext)
	for _, s := range editedSuffixes {
		if len(stem) > len(s) && strings.EqualFold(stem[len(stem)-len(s):], s) {
			return stem[:len(stem)-len(s)] + ext, true
		}
	}
	return name, false
}

// counterRe finds the "(n)" Google adds to a duplicate name, before the extension: "photo(1).jpg".
var counterRe = regexp.MustCompile(`^(.*)\(([1-9]\d{0,3})\)$`)

// splitCounter: "photo(1).jpg" → "photo.jpg", "(1)".
func splitCounter(name string) (string, string) {
	ext := path.Ext(name)
	if m := counterRe.FindStringSubmatch(strings.TrimSuffix(name, ext)); m != nil {
		return m[1] + ext, "(" + m[2] + ")"
	}
	return name, ""
}

const supplemental = ".supplemental-metadata"

// truncatedMin: Takeout cuts JSON names to 51 characters ("…" + ".json"), so a stem shorter than the
// media name is accepted only when it is long enough to be such a cut.
const truncatedMin = 40

// findSidecar returns the stem (name without ".json") of the JSON describing a media file, among the
// stems of its folder, handling Takeout's naming quirks:
//
//	photo.jpg            ← photo.jpg.json, photo.jpg.supplemental-metadata.json and its cuts
//	                       (.supplemental-metad.json, .suppl.json…), or a stem cut at 46–47 characters
//	photo(1).jpg         ← photo.jpg(1).json, photo.jpg.supplemental-metadata(1).json
//	photo-edited.jpg     ← the original's JSON (edited copies have none)
//
// Full names come first, then the counter variant, then cuts of the name itself, so a long "(1)" copy
// does not take its original's cut JSON. A cut stem in taken belongs to another file already, except
// for edited copies (shared). truncated reports a match on a cut of the name.
func findSidecar(name string, stems, taken map[string]bool) (stem string, truncated bool, ok bool) {
	if s, ok := lookup(name, "", stems, false, nil); ok {
		return s, false, true
	}
	base, counter := splitCounter(name)
	if counter != "" {
		if s, ok := lookup(base, counter, stems, false, nil); ok {
			return s, false, true
		}
		if s, ok := lookup(base, counter, stems, true, taken); ok {
			return s, true, true
		}
	}
	if s, ok := lookup(name, "", stems, true, taken); ok {
		return s, true, true
	}
	if orig, ok := unedited(name); ok {
		s, cut, found := findSidecar(orig, stems, nil)
		return s, cut, found
	}
	return "", false, false
}

// lookup tries name + every cut of ".supplemental-metadata", longest first (cuts == false), or cuts of
// the name itself when it is long enough to have been truncated (cuts == true); counter ("(1)")
// follows the cut, as Takeout writes it.
func lookup(name, counter string, stems map[string]bool, cuts bool, taken map[string]bool) (string, bool) {
	full := name + supplemental
	if cuts && utf8.RuneCountInString(name) <= truncatedMin {
		return "", false
	}
	hi, lo := len(full), len(name)
	if cuts {
		hi, lo = len(name)-1, 1
	}
	for l := hi; l >= lo; l-- {
		if l < len(full) && !utf8.RuneStart(full[l]) {
			continue // not at a character boundary
		}
		cut := full[:l]
		if cuts && utf8.RuneCountInString(cut) < truncatedMin {
			break
		}
		if key := cut + counter; stems[key] && !taken[key] {
			return key, true
		}
	}
	return "", false
}

// stemOf returns the stem of a JSON name ("photo.jpg.json" → "photo.jpg").
func stemOf(jsonName string) string { return jsonName[:len(jsonName)-len(".json")] }

// liveStem is the key pairing a Live Photo's image and video ("IMG_1.HEIC" + "IMG_1.MOV").
func liveStem(name string) string { return strings.ToLower(strings.TrimSuffix(name, path.Ext(name))) }
