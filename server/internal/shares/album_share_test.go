package shares_test

import (
	"bytes"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/albums"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
	"github.com/Paul-Carouge/Alcove/server/internal/shares"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

type albumEnv struct {
	*env
	album       *core.Record
	photo, gone *core.Record // media records; gone's file is in the trash
}

func albumSetup(t *testing.T) *albumEnv {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	media.Register(app)
	albums.Register(app)
	shares.Register(app)
	e := &albumEnv{env: &env{app: app}}
	e.alice, e.aliceTok = testutil.User(t, app, "alice@test.local")
	e.bob, e.bobTok = testutil.User(t, app, "bob@test.local")
	e.srv = testutil.Server(t, app).URL

	photo := func(name string) *core.Record {
		n := testutil.Node(t, app, e.alice, "", name, drive.KindFile)
		f, _ := filesystem.NewFileFromBytes(mediatest.JPEG(mediatest.Photo{
			Width: 64, Height: 48, Taken: time.Date(2025, 6, 1, 12, 0, 0, 0, time.UTC),
			Make: "Apple", Model: "iPhone 16", Lat: 45.764, Lon: 4.8357,
		}), name)
		n.Set("blob", f)
		if err := app.Save(n); err != nil {
			t.Fatal(err)
		}
		rec, err := app.FindFirstRecordByData(media.Collection, "node", n.Id)
		if err != nil {
			t.Fatal(err)
		}
		if err := media.Process(app, rec.Id); err != nil {
			t.Fatal(err)
		}
		rec, _ = app.FindRecordById(media.Collection, rec.Id)
		return rec
	}
	e.photo, e.gone = photo("lyon.jpg"), photo("old.jpg")

	col, _ := app.FindCollectionByNameOrId(albums.Collection)
	e.album = core.NewRecord(col)
	e.album.Set("owner", e.alice.Id)
	e.album.Set("name", "Lyon")
	e.album.Set("members", []string{e.bob.Id})
	if err := app.Save(e.album); err != nil {
		t.Fatal(err)
	}
	items, _ := app.FindCollectionByNameOrId(albums.Items)
	for _, m := range []*core.Record{e.photo, e.gone} {
		it := core.NewRecord(items)
		it.Set("album", e.album.Id)
		it.Set("media", m.Id)
		it.Set("added_by", e.alice.Id)
		if err := app.Save(it); err != nil {
			t.Fatal(err)
		}
	}
	node, _ := app.FindRecordById(drive.Collection, e.gone.GetString("node"))
	node.Set("trashed_at", time.Now())
	if err := app.Save(node); err != nil {
		t.Fatal(err)
	}
	return e
}

func (e *albumEnv) get(t *testing.T, path string) (int, []byte, http.Header) {
	t.Helper()
	res, err := http.Get(e.srv + path)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	b, _ := io.ReadAll(res.Body)
	return res.StatusCode, b, res.Header
}

func TestAlbumLinkCreation(t *testing.T) {
	e := albumSetup(t)
	for name, c := range map[string]struct {
		token string
		body  map[string]any
	}{
		"participant, not owner": {e.bobTok, map[string]any{"album": e.album.Id}},
		"both node and album":    {e.aliceTok, map[string]any{"album": e.album.Id, "node": e.photo.GetString("node")}},
		"neither":                {e.aliceTok, map[string]any{}},
		"unknown album":          {e.aliceTok, map[string]any{"album": "nope"}},
	} {
		if s, _, raw := e.req(t, http.MethodPost, "/api/v1/shares", c.token, c.body); s != http.StatusBadRequest {
			t.Errorf("%s: %d %s", name, s, raw)
		}
	}
}

func TestAlbumLinkShowsPreviewsWithoutPrivateData(t *testing.T) {
	e := albumSetup(t)
	token := e.share(t, map[string]any{"album": e.album.Id})

	s, out, raw := e.req(t, http.MethodGet, pub(token, ""), "", nil)
	if s != 200 {
		t.Fatalf("describe: %d %s", s, raw)
	}
	if out["album"].(map[string]any)["name"] != "Lyon" {
		t.Errorf("album = %v", out["album"])
	}
	items := out["media"].([]any)
	if len(items) != 1 || items[0].(map[string]any)["id"] != e.photo.Id || items[0].(map[string]any)["ready"] != true {
		t.Fatalf("media = %v (trashed items must be hidden)", items)
	}
	for _, leak := range []string{"lat", "lon", "45.76", "iPhone", "Apple", "camera", "has_location", e.alice.Email()} {
		if strings.Contains(raw, leak) {
			t.Errorf("public listing leaks %q: %s", leak, raw)
		}
	}

	s, body, h := e.get(t, pub(token, "/media/"+e.photo.Id+"/preview"))
	if s != 200 || h.Get("Content-Type") != "image/jpeg" || !bytes.HasPrefix(body, []byte{0xFF, 0xD8}) {
		t.Fatalf("preview: %d %s", s, h.Get("Content-Type"))
	}
	if bytes.Contains(body, []byte("Exif")) || bytes.Contains(body, []byte("iPhone")) {
		t.Error("preview carries EXIF metadata")
	}
	if s, _, _ := e.get(t, pub(token, "/media/"+e.photo.Id+"/thumb")); s != 200 {
		t.Errorf("thumb: %d", s)
	}
	for name, path := range map[string]string{
		"original photo":     "/media/" + e.photo.Id + "/video",
		"unknown variant":    "/media/" + e.photo.Id + "/original",
		"trashed item":       "/media/" + e.gone.Id + "/preview",
		"drive file by node": "/files/" + e.photo.GetString("node"),
	} {
		if s, _, _ := e.get(t, pub(token, path)); s != 404 {
			t.Errorf("%s: %d", name, s)
		}
	}
}

func TestAlbumLinkPasswordExpiryAndDeletion(t *testing.T) {
	e := albumSetup(t)
	token := e.share(t, map[string]any{"album": e.album.Id, "password": "summer"})
	if s, _, _ := e.get(t, pub(token, "/media/"+e.photo.Id+"/preview")); s != 401 {
		t.Errorf("locked preview: %d", s)
	}
	_, unlocked, _ := e.req(t, http.MethodPost, pub(token, "/unlock"), "", map[string]any{"password": "summer"})
	access := unlocked["access"].(string)
	if s, _, _ := e.get(t, pub(token, "/media/"+e.photo.Id+"/preview?access="+access)); s != 200 {
		t.Errorf("unlocked preview: %d", s)
	}

	share, _ := e.app.FindFirstRecordByData(shares.Collection, "album", e.album.Id)
	share.Set("expires_at", time.Now().Add(-time.Minute))
	if err := e.app.Save(share); err != nil {
		t.Fatal(err)
	}
	if s, _, _ := e.get(t, pub(token, "?access="+access)); s != 410 {
		t.Errorf("expired: %d", s)
	}

	other := e.share(t, map[string]any{"album": e.album.Id})
	if err := e.app.Delete(e.album); err != nil {
		t.Fatal(err)
	}
	if s, _, _ := e.get(t, pub(other, "")); s != 404 {
		t.Errorf("link survived its album: %d", s)
	}
}
