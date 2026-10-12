package media_test

import (
	"bytes"
	"image"
	"image/png"
	"math"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

type env struct {
	app        *tests.TestApp
	alice, bob *core.Record
	aliceTok   string
	bobTok     string
}

func setup(t *testing.T) *env {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	media.Register(app)
	e := &env{app: app}
	e.alice, e.aliceTok = testutil.User(t, app, "alice@test.local")
	e.bob, e.bobTok = testutil.User(t, app, "bob@test.local")
	return e
}

// upload stores a file node and returns its media record (processed synchronously).
func (e *env) upload(t *testing.T, name string, content []byte) *core.Record {
	t.Helper()
	n := testutil.Node(t, e.app, e.alice, "", name, drive.KindFile)
	f, err := filesystem.NewFileFromBytes(content, name)
	if err != nil {
		t.Fatal(err)
	}
	n.Set("blob", f)
	if err := e.app.Save(n); err != nil {
		t.Fatal(err)
	}
	rec, err := e.app.FindFirstRecordByData(media.Collection, "node", n.Id)
	if err != nil {
		return nil
	}
	if err := media.Process(e.app, rec.Id); err != nil {
		t.Fatalf("process: %v", err)
	}
	rec, _ = e.app.FindRecordById(media.Collection, rec.Id)
	return rec
}

func TestPhotoWithExif(t *testing.T) {
	e := setup(t)
	taken := time.Date(2023, 8, 2, 9, 41, 0, 0, time.UTC)
	rec := e.upload(t, "beach.jpg", mediatest.JPEG(mediatest.Photo{
		Width: 160, Height: 90, Taken: taken, Make: "Canon", Model: "EOS R6", Lat: 43.2965, Lon: 5.3698,
	}))
	if rec == nil || rec.GetString("status") != "ready" {
		t.Fatalf("media = %v", rec)
	}
	if got := rec.GetDateTime("taken_at").Time(); !got.Equal(taken) {
		t.Errorf("taken_at = %v", got)
	}
	if rec.GetInt("width") != 160 || rec.GetInt("height") != 90 || rec.GetString("kind") != "image" {
		t.Errorf("size/kind = %d×%d %s", rec.GetInt("width"), rec.GetInt("height"), rec.GetString("kind"))
	}
	if rec.GetString("camera_make") != "Canon" || rec.GetString("camera_model") != "EOS R6" {
		t.Errorf("camera = %q %q", rec.GetString("camera_make"), rec.GetString("camera_model"))
	}
	if !rec.GetBool("has_location") || math.Abs(rec.GetFloat("lat")-43.2965) > 1e-3 {
		t.Errorf("location = %v %v", rec.GetBool("has_location"), rec.GetFloat("lat"))
	}
	if rec.GetString("thumb") == "" || rec.GetString("preview") == "" {
		t.Error("every photo gets its own thumbnail and preview")
	}
}

func TestImageWithoutExifUsesUploadDate(t *testing.T) {
	e := setup(t)
	var buf bytes.Buffer
	_ = png.Encode(&buf, image.NewRGBA(image.Rect(0, 0, 30, 20)))
	rec := e.upload(t, "diagram.png", buf.Bytes())
	if rec.GetString("status") != "ready" || rec.GetInt("width") != 30 || rec.GetInt("height") != 20 {
		t.Fatalf("png media = %v", rec.PublicExport())
	}
	if rec.GetDateTime("taken_at").IsZero() {
		t.Error("taken_at should fall back to the upload date")
	}
}

func TestNonMediaIsIgnored(t *testing.T) {
	e := setup(t)
	if rec := e.upload(t, "notes.txt", []byte("hello")); rec != nil {
		t.Error("text file got a media record")
	}
	if rec := e.upload(t, "logo.svg", []byte(`<svg xmlns="http://www.w3.org/2000/svg"/>`)); rec != nil {
		t.Error("SVG got a media record")
	}
}

func TestVideo(t *testing.T) {
	if !media.HaveFFmpeg() {
		t.Skip("ffmpeg not installed")
	}
	e := setup(t)
	path := filepath.Join(t.TempDir(), "clip.mp4")
	out, err := exec.Command("ffmpeg", "-loglevel", "error", "-f", "lavfi", "-i", "testsrc=size=320x240:rate=10:duration=2",
		"-metadata", "creation_time=2022-05-01T10:20:30Z", "-metadata", "location=+48.8566+002.3522/",
		"-pix_fmt", "yuv420p", "-movflags", "+use_metadata_tags", "-y", path).CombinedOutput()
	if err != nil {
		t.Fatalf("ffmpeg: %v %s", err, out)
	}
	content, _ := os.ReadFile(path)
	rec := e.upload(t, "clip.mp4", content)
	if rec == nil || rec.GetString("status") != "ready" {
		t.Fatalf("video media = %v (error %q)", rec, rec.GetString("error"))
	}
	if d := rec.GetFloat("duration"); d < 1.5 || d > 2.5 {
		t.Errorf("duration = %v", d)
	}
	if rec.GetInt("width") != 320 || rec.GetInt("height") != 240 || rec.GetString("kind") != "video" {
		t.Errorf("video size/kind = %d×%d %s", rec.GetInt("width"), rec.GetInt("height"), rec.GetString("kind"))
	}
	if got := rec.GetDateTime("taken_at").Time().UTC().Format(time.RFC3339); got != "2022-05-01T10:20:30Z" {
		t.Errorf("taken_at = %s", got)
	}
	if !rec.GetBool("has_location") || math.Abs(rec.GetFloat("lon")-2.3522) > 1e-3 {
		t.Errorf("location = %v %v", rec.GetBool("has_location"), rec.GetFloat("lon"))
	}
	if rec.GetString("thumb") == "" || rec.GetString("preview") == "" {
		t.Error("video thumbnails missing")
	}
}

func TestBrokenVideoFails(t *testing.T) {
	if !media.HaveFFmpeg() {
		t.Skip("ffmpeg not installed")
	}
	e := setup(t)
	// A valid MP4 signature followed by garbage: sniffed as video, unreadable.
	junk := append([]byte("\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom"), bytes.Repeat([]byte{0xAB}, 4096)...)
	rec := e.upload(t, "broken.mp4", junk)
	if rec == nil || rec.GetString("status") != "failed" || !strings.Contains(rec.GetString("error"), "ffprobe") {
		t.Fatalf("broken video = %v", rec)
	}
}

func TestFavoriteAndCascade(t *testing.T) {
	e := setup(t)
	rec := e.upload(t, "fav.jpg", mediatest.JPEG(mediatest.Photo{Width: 10, Height: 10}))
	srv := testutil.Server(t, e.app).URL
	put := func(token, body string) int {
		req, _ := http.NewRequest(http.MethodPut, srv+"/api/v1/media/"+rec.Id+"/favorite", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", token)
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		_ = res.Body.Close()
		return res.StatusCode
	}
	if s := put(e.bobTok, `{"favorite":true}`); s != 404 {
		t.Errorf("other user: %d", s)
	}
	if s := put(e.aliceTok, `{"favorite":true}`); s != 204 {
		t.Fatalf("owner: %d", s)
	}
	if r, _ := e.app.FindRecordById(media.Collection, rec.Id); !r.GetBool("favorite") {
		t.Error("favorite not saved")
	}

	node, _ := e.app.FindRecordById(drive.Collection, rec.GetString("node"))
	if err := e.app.Delete(node); err != nil {
		t.Fatal(err)
	}
	if _, err := e.app.FindRecordById(media.Collection, rec.Id); err == nil {
		t.Error("media survived its file")
	}
}

func TestUsersCannotWriteMediaDirectly(t *testing.T) {
	e := setup(t)
	rec := e.upload(t, "x.jpg", mediatest.JPEG(mediatest.Photo{Width: 10, Height: 10}))
	scenario := tests.ApiScenario{
		Name: "update through the collection API is refused", Method: http.MethodPatch,
		URL:            "/api/collections/media/records/" + rec.Id,
		Headers:        map[string]string{"Authorization": e.aliceTok},
		Body:           strings.NewReader(`{"taken_at":"1999-01-01 00:00:00.000Z"}`),
		TestAppFactory: func(testing.TB) *tests.TestApp { return e.app }, DisableTestAppCleanup: true,
		ExpectedStatus: 403, ExpectedContent: []string{`"status":403`},
	}
	scenario.Test(t)
}

// testdata/iphone.heic was made with macOS sips from a mediatest JPEG
// (640×480, taken 2025-06-01 12:00 UTC, Apple iPhone 16, Lyon).
func TestHEIC(t *testing.T) {
	if !media.HEICSupported() {
		t.Skip("needs ffmpeg 7.1 or newer")
	}
	e := setup(t)
	content, err := os.ReadFile("testdata/iphone.heic")
	if err != nil {
		t.Fatal(err)
	}
	rec := e.upload(t, "IMG_0001.HEIC", content)
	if rec == nil || rec.GetString("status") != "ready" {
		t.Fatalf("heic media = %v (error %q)", rec, rec.GetString("error"))
	}
	if rec.GetString("kind") != "image" || rec.GetString("thumb") == "" || rec.GetString("preview") == "" {
		t.Errorf("kind %q, thumb %q, preview %q", rec.GetString("kind"), rec.GetString("thumb"), rec.GetString("preview"))
	}
	if rec.GetString("camera_model") != "iPhone 16" {
		t.Errorf("camera = %q (EXIF not read from HEIC)", rec.GetString("camera_model"))
	}
	if got := rec.GetDateTime("taken_at").Time().UTC().Format("2006-01-02"); got != "2025-06-01" {
		t.Errorf("taken_at = %s", got)
	}
}

func TestFilesFromBeforeThePhotosModuleAreTracked(t *testing.T) {
	e := setup(t)
	rec := e.upload(t, "old.jpg", mediatest.JPEG(mediatest.Photo{Width: 20, Height: 10}))
	node := rec.GetString("node")
	// As if the file had been uploaded before v0.10: no media record.
	if err := e.app.Delete(rec); err != nil {
		t.Fatal(err)
	}
	media.Backfill(e.app)
	got, err := e.app.FindFirstRecordByData(media.Collection, "node", node)
	if err != nil {
		t.Fatal("pre-existing photo not tracked")
	}
	if err := media.Process(e.app, got.Id); err != nil {
		t.Fatal(err)
	}
	got, _ = e.app.FindRecordById(media.Collection, got.Id)
	if got.GetString("status") != "ready" || got.GetString("thumb") == "" {
		t.Errorf("status %q thumb %q", got.GetString("status"), got.GetString("thumb"))
	}
}

func TestPerceptualHashIsBackfilled(t *testing.T) {
	e := setup(t)
	rec := e.upload(t, "p.jpg", mediatest.JPEG(mediatest.Photo{Width: 80, Height: 60}))
	if len(rec.GetString("phash")) != 22 {
		t.Fatalf("phash = %q", rec.GetString("phash"))
	}
	// As if processed before v0.13.
	rec.Set("phash", "")
	if err := e.app.Save(rec); err != nil {
		t.Fatal(err)
	}
	media.Backfill(e.app)
	got, _ := e.app.FindRecordById(media.Collection, rec.Id)
	if len(got.GetString("phash")) != 22 {
		t.Errorf("phash not backfilled: %q", got.GetString("phash"))
	}
}

func TestFacets(t *testing.T) {
	e := setup(t)
	e.upload(t, "a.jpg", mediatest.JPEG(mediatest.Photo{Width: 10, Height: 10, Make: "Apple", Model: "iPhone 16",
		Taken: time.Date(2025, 6, 1, 0, 0, 0, 0, time.UTC), Lat: 45, Lon: 4}))
	e.upload(t, "b.jpg", mediatest.JPEG(mediatest.Photo{Width: 10, Height: 10, Make: "Apple", Model: "iPhone 16",
		Taken: time.Date(2025, 8, 1, 0, 0, 0, 0, time.UTC)}))
	e.upload(t, "c.jpg", mediatest.JPEG(mediatest.Photo{Width: 10, Height: 10, Make: "FUJIFILM", Model: "X-T5",
		Taken: time.Date(2023, 1, 1, 0, 0, 0, 0, time.UTC)}))
	scenario := tests.ApiScenario{
		Name: "facets of alice's photos", Method: http.MethodGet, URL: "/api/v1/photos/facets",
		Headers:        map[string]string{"Authorization": e.aliceTok},
		TestAppFactory: func(testing.TB) *tests.TestApp { return e.app }, DisableTestAppCleanup: true,
		ExpectedStatus: 200,
		ExpectedContent: []string{`"years":[{"year":2025,"count":2},{"year":2023,"count":1}]`,
			`{"make":"Apple","model":"iPhone 16","count":2}`, `"withLocation":1`},
	}
	scenario.Test(t)
	located := tests.ApiScenario{
		Name: "only located photos on the map", Method: http.MethodGet, URL: "/api/v1/photos/locations",
		Headers:        map[string]string{"Authorization": e.aliceTok},
		TestAppFactory: func(testing.TB) *tests.TestApp { return e.app }, DisableTestAppCleanup: true,
		ExpectedStatus: 200, ExpectedContent: []string{`"lat":45`, `"lon":4`, `"collectionId":"`},
		NotExpectedContent: []string{`"lat":0`},
	}
	located.Test(t)
	empty := tests.ApiScenario{
		Name: "bob has none", Method: http.MethodGet, URL: "/api/v1/photos/facets",
		Headers:        map[string]string{"Authorization": e.bobTok},
		TestAppFactory: func(testing.TB) *tests.TestApp { return e.app }, DisableTestAppCleanup: true,
		ExpectedStatus: 200, ExpectedContent: []string{`"years":[]`, `"cameras":[]`, `"withLocation":0`},
	}
	empty.Test(t)
}

// testdata/tiled.heic: a 1536×1024 picture stored as 512-pixel tiles, like phone cameras do (made with
// libheif's heif-enc --cut-tiles from a mediatest JPEG: 2025-08-15, OPPO Find X9 Pro, Paris).
func TestTiledHEIC(t *testing.T) {
	if !media.HEICSupported() {
		t.Skip("needs ffmpeg 7.1 or newer")
	}
	e := setup(t)
	content, err := os.ReadFile("testdata/tiled.heic")
	if err != nil {
		t.Fatal(err)
	}
	rec := e.upload(t, "IMG_0002.HEIC", content)
	if rec == nil || rec.GetString("status") != "ready" || rec.GetString("thumb") == "" {
		t.Fatalf("tiled heic = %v (error %q)", rec, rec.GetString("error"))
	}
	if rec.GetString("camera_model") != "Find X9 Pro" || !rec.GetBool("has_location") {
		t.Errorf("metadata: model %q, location %v", rec.GetString("camera_model"), rec.GetBool("has_location"))
	}
	if rec.GetInt("width") != 1536 || rec.GetInt("height") != 1024 {
		t.Errorf("size = %dx%d", rec.GetInt("width"), rec.GetInt("height"))
	}
}
