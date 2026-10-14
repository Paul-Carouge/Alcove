package uploads_test

import (
	"net/http"
	"strings"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/uploads"
)

// An empty file is still a file: the node exists as soon as the upload is created.
func TestEmptyFile(t *testing.T) {
	e := setup(t)
	res := do(t, http.MethodPost, e.url, e.aliceTok, map[string]string{
		"Upload-Length": "0", "Upload-Metadata": meta("filename", "empty.txt"),
	}, "")
	// Nothing to send: the creation response already names the node.
	id := res.Header.Get(uploads.NodeHeader)
	if res.StatusCode != http.StatusCreated || id == "" {
		t.Fatalf("empty upload: status %d, node %q", res.StatusCode, id)
	}
	node, err := e.app.FindRecordById(drive.Collection, id)
	if err != nil || node.GetInt("size") != 0 || node.GetString("name") != "empty.txt" {
		t.Fatalf("node = %v, %v", node, err)
	}
}

func TestNamesFromPhonesAndOtherSystems(t *testing.T) {
	e := setup(t)
	for _, name := range []string{
		"Été à Lyon 🌞.jpg",                // accents and emoji
		"IMG 0001 (copie).HEIC",           // spaces and parentheses
		strings.Repeat("a", 250) + ".txt", // 254 characters
		"日本語のファイル.pdf",                    // not Latin
		".hidden",                         // starts with a dot
	} {
		loc := e.create(t, e.aliceTok, 1, meta("filename", name))
		res := patch(t, loc, e.aliceTok, 0, "x")
		node, err := e.app.FindRecordById(drive.Collection, res.Header.Get(uploads.NodeHeader))
		if err != nil || node.GetString("name") != name {
			t.Errorf("%q: stored as %q (%v)", name, node.GetString("name"), err)
		}
	}
	for _, bad := range []string{"", "a/b.txt", "..", strings.Repeat("a", 256), "tab\tin.txt"} {
		res := do(t, http.MethodPost, e.url, e.aliceTok, map[string]string{
			"Upload-Length": "1", "Upload-Metadata": meta("filename", bad),
		}, "")
		if res.StatusCode != http.StatusBadRequest {
			t.Errorf("%q: status %d, want 400", bad, res.StatusCode)
		}
	}
}

// A chunk sent at the wrong offset (a client that lost track) is refused, not appended.
func TestWrongOffsetIsRefused(t *testing.T) {
	e := setup(t)
	loc := e.create(t, e.aliceTok, 11, meta("filename", "hello.txt"))
	if res := patch(t, loc, e.aliceTok, 3, "lo world"); res.StatusCode != http.StatusConflict {
		t.Errorf("status %d, want 409", res.StatusCode)
	}
	head := do(t, http.MethodHead, loc, e.aliceTok, nil, "")
	if got := head.Header.Get("Upload-Offset"); got != "0" {
		t.Errorf("offset = %s", got)
	}
}
