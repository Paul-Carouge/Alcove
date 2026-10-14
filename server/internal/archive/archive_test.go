package archive_test

import (
	"archive/zip"
	"bytes"
	"encoding/json"
	"io"
	"net/http"
	"sort"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/albums"
	"github.com/Paul-Carouge/Alcove/server/internal/archive"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

type env struct {
	app              *tests.TestApp
	srv              string
	alice, bob       *core.Record
	aliceTok, bobTok string
}

func setup(t *testing.T) *env {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	media.Register(app)
	albums.Register(app)
	archive.Register(app)
	e := &env{app: app}
	e.alice, e.aliceTok = testutil.User(t, app, "alice@test.local")
	e.bob, e.bobTok = testutil.User(t, app, "bob@test.local")
	e.srv = testutil.Server(t, app).URL
	return e
}

func (e *env) file(t *testing.T, owner *core.Record, parent, name string, content []byte) *core.Record {
	t.Helper()
	n := testutil.Node(t, e.app, owner, parent, name, drive.KindFile)
	f, _ := filesystem.NewFileFromBytes(content, name)
	n.Set("blob", f)
	if err := e.app.Save(n); err != nil {
		t.Fatal(err)
	}
	return n
}

func (e *env) ticket(t *testing.T, token string, body any) (int, map[string]any) {
	t.Helper()
	b, _ := json.Marshal(body)
	req, _ := http.NewRequest(http.MethodPost, e.srv+"/api/v1/zip", bytes.NewReader(b))
	req.Header.Set("Authorization", token)
	req.Header.Set("Content-Type", "application/json")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	var out map[string]any
	_ = json.NewDecoder(res.Body).Decode(&out)
	return res.StatusCode, out
}

func (e *env) fetch(t *testing.T, url string) (map[string]string, http.Header) {
	t.Helper()
	res, err := http.Get(e.srv + url)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	if res.StatusCode != http.StatusOK {
		t.Fatalf("GET %s: %d", url, res.StatusCode)
	}
	data, _ := io.ReadAll(res.Body)
	zr, err := zip.NewReader(bytes.NewReader(data), int64(len(data)))
	if err != nil {
		t.Fatal(err)
	}
	files := map[string]string{}
	for _, f := range zr.File {
		rc, _ := f.Open()
		b, _ := io.ReadAll(rc)
		_ = rc.Close()
		files[f.Name] = string(b)
	}
	return files, res.Header
}

func keys(m map[string]string) string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return strings.Join(out, ",")
}

func TestFoldersAndFiles(t *testing.T) {
	e := setup(t)
	docs := testutil.Node(t, e.app, e.alice, "", "Docs", drive.KindFolder)
	testutil.Node(t, e.app, e.alice, docs.Id, "Empty", drive.KindFolder)
	e.file(t, e.alice, docs.Id, "a.txt", []byte("alpha"))
	gone := e.file(t, e.alice, docs.Id, "old.txt", []byte("old"))
	gone.Set("trashed_at", time.Now())
	if err := e.app.Save(gone); err != nil {
		t.Fatal(err)
	}
	elsewhere := testutil.Node(t, e.app, e.alice, "", "Elsewhere", drive.KindFolder)
	other := e.file(t, e.alice, elsewhere.Id, "Docs", []byte("a file named like the folder"))

	code, out := e.ticket(t, e.aliceTok, map[string]any{"nodes": []string{docs.Id, other.Id}})
	if code != 200 || out["files"].(float64) != 3 {
		t.Fatalf("ticket: %d %v", code, out)
	}
	files, h := e.fetch(t, out["url"].(string))
	if got := keys(files); got != "Docs (2),Docs/Empty/,Docs/a.txt" {
		t.Errorf("entries = %s", got)
	}
	if files["Docs/a.txt"] != "alpha" {
		t.Errorf("content = %q", files["Docs/a.txt"])
	}
	if !strings.Contains(h.Get("Content-Disposition"), `Alcove.zip`) || h.Get("Content-Type") != "application/zip" {
		t.Errorf("headers = %v", h)
	}

	// Others' files and bad requests are refused.
	if code, _ := e.ticket(t, e.bobTok, map[string]any{"nodes": []string{docs.Id}}); code != 404 {
		t.Errorf("bob: %d", code)
	}
	if code, _ := e.ticket(t, e.aliceTok, map[string]any{"nodes": []string{gone.Id}}); code != 404 {
		t.Errorf("trashed: %d", code)
	}
	if code, _ := e.ticket(t, e.aliceTok, map[string]any{}); code != 400 {
		t.Errorf("empty request: %d", code)
	}
	if res, _ := http.Get(e.srv + "/api/v1/zip/not-a-ticket"); res.StatusCode != http.StatusNotFound {
		t.Errorf("unknown ticket: %d", res.StatusCode)
	}
}

func TestAlbum(t *testing.T) {
	e := setup(t)
	photo := func(folder, name string) *core.Record {
		parent := testutil.Node(t, e.app, e.alice, "", folder, drive.KindFolder)
		n := e.file(t, e.alice, parent.Id, name, mediatest.JPEG(mediatest.Photo{Width: 32, Height: 24, Taken: time.Now()}))
		rec, err := e.app.FindFirstRecordByData(media.Collection, "node", n.Id)
		if err != nil {
			t.Fatal(err)
		}
		if err := media.Process(e.app, rec.Id); err != nil {
			t.Fatal(err)
		}
		return rec
	}
	a, b := photo("2024", "same.jpg"), photo("2025", "same.jpg")
	col, _ := e.app.FindCollectionByNameOrId(albums.Collection)
	album := core.NewRecord(col)
	album.Set("owner", e.alice.Id)
	album.Set("name", "Été / plage")
	album.Set("members", []string{e.bob.Id})
	if err := e.app.Save(album); err != nil {
		t.Fatal(err)
	}
	items, _ := e.app.FindCollectionByNameOrId(albums.Items)
	for _, m := range []*core.Record{a, b} {
		it := core.NewRecord(items)
		it.Set("album", album.Id)
		it.Set("media", m.Id)
		it.Set("added_by", e.alice.Id)
		if err := e.app.Save(it); err != nil {
			t.Fatal(err)
		}
	}
	// A member downloads the album; the name is made safe for a file.
	code, out := e.ticket(t, e.bobTok, map[string]any{"album": album.Id})
	if code != 200 {
		t.Fatalf("member: %d %v", code, out)
	}
	files, h := e.fetch(t, out["url"].(string))
	if got := keys(files); got != "same (2).jpg,same.jpg" {
		t.Errorf("entries = %s", got)
	}
	if !strings.Contains(h.Get("Content-Disposition"), "plage.zip") || strings.Contains(h.Get("Content-Disposition"), "/") {
		t.Errorf("disposition = %s", h.Get("Content-Disposition"))
	}
	stranger, strangerTok := testutil.User(t, e.app, "eve@test.local")
	_ = stranger
	if code, _ := e.ticket(t, strangerTok, map[string]any{"album": album.Id}); code != 404 {
		t.Errorf("stranger: %d", code)
	}
}
