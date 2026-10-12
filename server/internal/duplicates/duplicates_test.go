package duplicates_test

import (
	"bytes"
	"encoding/json"
	"image"
	"image/color"
	"image/jpeg"
	"io"
	"math/rand/v2"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/duplicates"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

// picture renders a random but reproducible scene at the given size.
func picture(seed uint64, w, h int) []byte {
	r := rand.New(rand.NewPCG(seed, seed))
	img := image.NewRGBA(image.Rect(0, 0, w, h))
	blocks := [8][8]color.RGBA{}
	for y := range blocks {
		for x := range blocks[y] {
			blocks[y][x] = color.RGBA{uint8(r.IntN(256)), uint8(r.IntN(256)), uint8(r.IntN(256)), 255}
		}
	}
	for y := range h {
		for x := range w {
			img.Set(x, y, blocks[y*8/h][x*8/w])
		}
	}
	var buf bytes.Buffer
	_ = jpeg.Encode(&buf, img, &jpeg.Options{Quality: 90})
	return buf.Bytes()
}

type env struct {
	t     *testing.T
	app   *tests.TestApp
	srv   string
	alice *core.Record
	tok   string
}

func (e *env) upload(owner *core.Record, name string, content []byte) *core.Record {
	e.t.Helper()
	n := testutil.Node(e.t, e.app, owner, "", name, drive.KindFile)
	f, _ := filesystem.NewFileFromBytes(content, name)
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

type group struct {
	Kind  string `json:"kind"`
	Keep  string `json:"keep"`
	Items []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"items"`
}

func (e *env) groups() []group {
	e.t.Helper()
	req, _ := http.NewRequest(http.MethodGet, e.srv+"/api/v1/photos/duplicates", nil)
	req.Header.Set("Authorization", e.tok)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		e.t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	var out struct{ Groups []group }
	if err := json.NewDecoder(res.Body).Decode(&out); err != nil {
		e.t.Fatal(err)
	}
	return out.Groups
}

func names(g group) string {
	var n []string
	for _, it := range g.Items {
		n = append(n, it.Name)
	}
	return strings.Join(n, ",")
}

func TestDuplicates(t *testing.T) {
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	media.Register(app)
	duplicates.Register(app)
	e := &env{t: t, app: app}
	e.alice, e.tok = testutil.User(t, app, "alice@test.local")
	bob, _ := testutil.User(t, app, "bob@test.local")
	e.srv = testutil.Server(t, app).URL

	beach := picture(1, 800, 600)
	original := e.upload(e.alice, "beach.jpg", beach)
	e.upload(e.alice, "beach copy.jpg", beach)                 // identical bytes
	e.upload(e.alice, "beach small.jpg", picture(1, 400, 300)) // same scene, resized
	e.upload(e.alice, "city.jpg", picture(2, 800, 600))        // different
	e.upload(bob, "beach.jpg", beach)                          // someone else's copy
	trashed := e.upload(e.alice, "beach old.jpg", beach)
	node, _ := app.FindRecordById(drive.Collection, trashed.GetString("node"))
	node.Set("trashed_at", time.Now())
	_ = app.Save(node)

	got := e.groups()
	if len(got) != 1 || got[0].Kind != "similar" || len(got[0].Items) != 3 {
		t.Fatalf("groups = %+v", got)
	}
	if !strings.Contains(names(got[0]), "beach small.jpg") || strings.Contains(names(got[0]), "city") ||
		strings.Contains(names(got[0]), "old") {
		t.Errorf("group members = %s", names(got[0]))
	}
	if got[0].Keep != original.Id && !strings.Contains(names(got[0]), "copy") {
		t.Errorf("keep suggestion = %s", got[0].Keep)
	}

	// Dismissing hides the group, until another similar photo joins.
	var ids []string
	for _, it := range got[0].Items {
		ids = append(ids, it.ID)
	}
	body, _ := json.Marshal(map[string]any{"items": ids})
	req, _ := http.NewRequest(http.MethodPost, e.srv+"/api/v1/photos/duplicates/dismiss", bytes.NewReader(body))
	req.Header.Set("Authorization", e.tok)
	req.Header.Set("Content-Type", "application/json")
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	_, _ = io.Copy(io.Discard, res.Body)
	_ = res.Body.Close()
	if res.StatusCode != http.StatusNoContent {
		t.Fatalf("dismiss: %d", res.StatusCode)
	}
	if g := e.groups(); len(g) != 0 {
		t.Fatalf("dismissed group still listed: %+v", g)
	}
	e.upload(e.alice, "beach again.jpg", picture(1, 640, 480))
	if g := e.groups(); len(g) != 1 || len(g[0].Items) != 4 {
		t.Fatalf("group with a new member should show again: %+v", g)
	}

	// Only your own items can be dismissed.
	other, _ := app.FindFirstRecordByFilter(media.Collection, "owner = {:o}", map[string]any{"o": bob.Id})
	body, _ = json.Marshal(map[string]any{"items": []string{original.Id, other.Id}})
	req, _ = http.NewRequest(http.MethodPost, e.srv+"/api/v1/photos/duplicates/dismiss", bytes.NewReader(body))
	req.Header.Set("Authorization", e.tok)
	req.Header.Set("Content-Type", "application/json")
	res, _ = http.DefaultClient.Do(req)
	_ = res.Body.Close()
	if res.StatusCode != http.StatusBadRequest {
		t.Errorf("dismiss someone else's item: %d", res.StatusCode)
	}
}
