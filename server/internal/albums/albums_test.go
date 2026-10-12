package albums_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/albums"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

type env struct {
	t                    *testing.T
	app                  *tests.TestApp
	srv                  string
	alice, bob, carol    *core.Record
	aliceTok, bobTok, ct string
}

func setup(t *testing.T) *env {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	media.Register(app)
	albums.Register(app)
	e := &env{t: t, app: app}
	e.alice, e.aliceTok = testutil.User(t, app, "alice@test.local")
	e.bob, e.bobTok = testutil.User(t, app, "bob@test.local")
	e.carol, e.ct = testutil.User(t, app, "carol@test.local")
	e.srv = testutil.Server(t, app).URL
	return e
}

// photo stores a processed photo owned by user and returns its media record.
func (e *env) photo(owner *core.Record, name string, taken time.Time) *core.Record {
	e.t.Helper()
	n := testutil.Node(e.t, e.app, owner, "", name, drive.KindFile)
	f, _ := filesystem.NewFileFromBytes(mediatest.JPEG(mediatest.Photo{Width: 40, Height: 30, Taken: taken}), name)
	n.Set("blob", f)
	if err := e.app.Save(n); err != nil {
		e.t.Fatal(err)
	}
	rec, err := e.app.FindFirstRecordByData(media.Collection, "node", n.Id)
	if err != nil {
		e.t.Fatal(err)
	}
	if err := media.Process(e.app, rec.Id); err != nil {
		e.t.Fatal(err)
	}
	rec, _ = e.app.FindRecordById(media.Collection, rec.Id)
	return rec
}

func (e *env) call(method, path, token, body string) (int, map[string]any) {
	e.t.Helper()
	req, _ := http.NewRequest(method, e.srv+path, strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		e.t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	b, _ := io.ReadAll(res.Body)
	var out map[string]any
	_ = json.Unmarshal(b, &out)
	return res.StatusCode, out
}

func (e *env) fileToken(user *core.Record) string {
	e.t.Helper()
	tok, err := user.NewFileToken()
	if err != nil {
		e.t.Fatal(err)
	}
	return tok
}

func (e *env) newAlbum(token, owner, name string) string {
	e.t.Helper()
	s, out := e.call("POST", "/api/collections/albums/records", token, `{"owner":"`+owner+`","name":"`+name+`"}`)
	if s != 200 {
		e.t.Fatalf("create album: %d %v", s, out)
	}
	return out["id"].(string)
}

func (e *env) add(token, album, mediaID, by string) (int, string) {
	e.t.Helper()
	s, out := e.call("POST", "/api/collections/album_items/records", token,
		`{"album":"`+album+`","media":"`+mediaID+`","added_by":"`+by+`"}`)
	id, _ := out["id"].(string)
	return s, id
}

func (e *env) share(album, field string, users ...string) {
	e.t.Helper()
	body, _ := json.Marshal(map[string]any{field: users})
	if s, out := e.call("PATCH", "/api/collections/albums/records/"+album, e.aliceTok, string(body)); s != 200 {
		e.t.Fatalf("share: %d %v", s, out)
	}
}

func (e *env) itemCount(token, album string) int {
	e.t.Helper()
	s, out := e.call("GET", "/api/v1/albums/"+album+"/items", token, "")
	if s != 200 {
		return -s
	}
	return int(out["totalItems"].(float64))
}

func TestAlbumLifecycleAndRules(t *testing.T) {
	e := setup(t)
	beach := e.photo(e.alice, "beach.jpg", time.Date(2025, 7, 1, 10, 0, 0, 0, time.UTC))
	city := e.photo(e.alice, "city.jpg", time.Date(2025, 8, 1, 10, 0, 0, 0, time.UTC))

	// Albums are created for yourself only.
	if s, _ := e.call("POST", "/api/collections/albums/records", e.bobTok, `{"owner":"`+e.alice.Id+`","name":"x"}`); s == 200 {
		t.Fatal("bob created an album owned by alice")
	}
	album := e.newAlbum(e.aliceTok, e.alice.Id, "Summer")
	if s, _ := e.add(e.aliceTok, album, beach.Id, e.alice.Id); s != 200 {
		t.Fatalf("add own photo: %d", s)
	}
	if s, _ := e.add(e.aliceTok, album, beach.Id, e.alice.Id); s == 200 {
		t.Error("same photo added twice")
	}
	if _, id := e.add(e.aliceTok, album, city.Id, e.alice.Id); id == "" {
		t.Fatal("add second photo")
	}

	// Not shared yet: bob sees nothing.
	if n := e.itemCount(e.bobTok, album); n != -404 {
		t.Errorf("bob items: %d", n)
	}
	if s, _ := e.call("GET", "/api/collections/media/records/"+beach.Id, e.bobTok, ""); s != 404 {
		t.Errorf("bob views media before sharing: %d", s)
	}
	if s, _ := e.call("GET", "/api/v1/media/"+beach.Id+"/original?token="+e.fileToken(e.bob), "", ""); s != 404 {
		t.Errorf("bob downloads before sharing: %d", s)
	}

	// Viewer: sees the album, its photos and originals; cannot add, change or remove.
	e.share(album, "members", e.bob.Id)
	_, list := e.call("GET", "/api/v1/albums", e.bobTok, "")
	got := list["items"].([]any)
	if len(got) != 1 || got[0].(map[string]any)["role"] != albums.RoleViewer || got[0].(map[string]any)["count"].(float64) != 2 {
		t.Fatalf("bob's albums = %v", got)
	}
	if cover := got[0].(map[string]any)["cover"].(map[string]any); cover["id"] != city.Id {
		t.Errorf("default cover = %v, want the newest photo", cover["id"])
	}
	if n := e.itemCount(e.bobTok, album); n != 2 {
		t.Errorf("viewer items: %d", n)
	}
	if s, _ := e.call("GET", "/api/collections/media/records/"+beach.Id, e.bobTok, ""); s != 200 {
		t.Errorf("viewer views shared media: %d", s)
	}
	if s, _ := e.call("GET", "/api/v1/media/"+beach.Id+"/original?token="+e.fileToken(e.bob), "", ""); s != 200 {
		t.Errorf("viewer downloads shared original: %d", s)
	}
	if s, out := e.call("GET", "/api/collections/media/records", e.bobTok, ""); s != 200 || out["totalItems"].(float64) != 0 {
		t.Errorf("shared photos leak into bob's timeline: %v", out)
	}
	if s, _ := e.call("GET", "/api/collections/nodes/records/"+beach.GetString("node"), e.bobTok, ""); s != 404 {
		t.Errorf("drive file readable by viewer: %d", s)
	}
	bobPhoto := e.photo(e.bob, "bob.jpg", time.Now())
	if s, _ := e.add(e.bobTok, album, bobPhoto.Id, e.bob.Id); s == 200 {
		t.Error("viewer added a photo")
	}
	if s, _ := e.call("PATCH", "/api/collections/albums/records/"+album, e.bobTok, `{"name":"mine"}`); s != 404 {
		t.Errorf("viewer renamed album: %d", s)
	}
	if s, _ := e.call("GET", "/api/v1/albums/"+album+"/items", e.ct, ""); s != 404 {
		t.Errorf("carol sees the album: %d", s)
	}

	// Contributor: adds only their own photos, removes only their own items.
	e.share(album, "contributors", e.bob.Id)
	if r, _ := e.app.FindRecordById(albums.Collection, album); len(r.GetStringSlice("members")) != 0 {
		t.Error("a person kept two roles")
	}
	if s, _ := e.add(e.bobTok, album, bobPhoto.Id, e.alice.Id); s == 200 {
		t.Error("contributor added a photo in someone else's name")
	}
	carolPhoto := e.photo(e.carol, "carol.jpg", time.Now())
	if s, _ := e.add(e.bobTok, album, carolPhoto.Id, e.bob.Id); s == 200 {
		t.Error("contributor added someone else's photo")
	}
	s, bobItem := e.add(e.bobTok, album, bobPhoto.Id, e.bob.Id)
	if s != 200 {
		t.Fatalf("contributor adds own photo: %d", s)
	}
	if s, _ := e.call("GET", "/api/collections/media/records/"+bobPhoto.Id, e.aliceTok, ""); s != 200 {
		t.Errorf("owner views contributed photo: %d", s)
	}
	items, _ := e.app.FindAllRecords(albums.Items)
	for _, it := range items {
		if it.GetString("added_by") == e.alice.Id {
			if s, _ := e.call("DELETE", "/api/collections/album_items/records/"+it.Id, e.bobTok, ""); s != 404 {
				t.Errorf("contributor removed alice's item: %d", s)
			}
			break
		}
	}

	// Removing the contributor removes their photos and their access.
	e.share(album, "contributors")
	if _, err := e.app.FindRecordById(albums.Items, bobItem); err == nil {
		t.Error("removed contributor's photo stayed in the album")
	}
	if s, _ := e.call("GET", "/api/collections/media/records/"+beach.Id, e.bobTok, ""); s != 404 {
		t.Errorf("access survived removal: %d", s)
	}
}

func TestCoverTrashAndLeave(t *testing.T) {
	e := setup(t)
	a := e.photo(e.alice, "a.jpg", time.Date(2024, 1, 1, 0, 0, 0, 0, time.UTC))
	b := e.photo(e.alice, "b.jpg", time.Date(2024, 2, 1, 0, 0, 0, 0, time.UTC))
	outside := e.photo(e.alice, "c.jpg", time.Now())
	album := e.newAlbum(e.aliceTok, e.alice.Id, "Winter")
	_, itemA := e.add(e.aliceTok, album, a.Id, e.alice.Id)
	e.add(e.aliceTok, album, b.Id, e.alice.Id)

	if s, _ := e.call("PATCH", "/api/collections/albums/records/"+album, e.aliceTok, `{"cover":"`+outside.Id+`"}`); s != 400 {
		t.Errorf("cover outside the album: %d", s)
	}
	if s, _ := e.call("PATCH", "/api/collections/albums/records/"+album, e.aliceTok, `{"cover":"`+a.Id+`"}`); s != 200 {
		t.Fatalf("set cover: %d", s)
	}
	if s, _ := e.call("DELETE", "/api/collections/album_items/records/"+itemA, e.aliceTok, ""); s != 204 {
		t.Fatalf("remove item: %d", s)
	}
	if r, _ := e.app.FindRecordById(albums.Collection, album); r.GetString("cover") != "" {
		t.Error("cover kept after its photo left the album")
	}

	// Files in the trash disappear from albums and cannot be downloaded through them.
	e.share(album, "members", e.bob.Id)
	node, _ := e.app.FindRecordById(drive.Collection, b.GetString("node"))
	node.Set("trashed_at", time.Now())
	if err := e.app.Save(node); err != nil {
		t.Fatal(err)
	}
	if n := e.itemCount(e.bobTok, album); n != 0 {
		t.Errorf("trashed photo listed: %d", n)
	}
	if s, _ := e.call("GET", "/api/v1/media/"+b.Id+"/original?token="+e.fileToken(e.bob), "", ""); s != 404 {
		t.Errorf("trashed original served: %d", s)
	}

	// People and leaving.
	s, people := e.call("GET", "/api/v1/albums/"+album+"/people", e.bobTok, "")
	if s != 200 || people["owner"].(map[string]any)["email"] != "alice@test.local" || len(people["people"].([]any)) != 1 {
		t.Fatalf("people = %d %v", s, people)
	}
	if s, _ := e.call("POST", "/api/v1/albums/"+album+"/leave", e.aliceTok, ""); s != 400 {
		t.Errorf("owner left: %d", s)
	}
	if s, _ := e.call("POST", "/api/v1/albums/"+album+"/leave", e.bobTok, ""); s != 204 {
		t.Fatalf("leave: %d", s)
	}
	if s, _ := e.call("GET", "/api/v1/albums/"+album+"/items", e.bobTok, ""); s != 404 {
		t.Errorf("still in the album after leaving: %d", s)
	}
}

func TestLookup(t *testing.T) {
	e := setup(t)
	if s, out := e.call("GET", "/api/v1/users/lookup?email=BOB@test.local", e.aliceTok, ""); s != 200 || out["id"] != e.bob.Id {
		t.Errorf("lookup bob: %d %v", s, out)
	}
	for _, q := range []string{"nobody@test.local", "alice@test.local"} {
		if s, _ := e.call("GET", "/api/v1/users/lookup?email="+q, e.aliceTok, ""); s != 404 {
			t.Errorf("lookup %s: %d", q, s)
		}
	}
	if s, _ := e.call("GET", "/api/v1/users/lookup?email=bob@test.local", "", ""); s != 401 {
		t.Errorf("anonymous lookup: %d", s)
	}
}
