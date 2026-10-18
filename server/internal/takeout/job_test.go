package takeout

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	"github.com/Paul-Carouge/Alcove/server/internal/albums"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

const (
	lib13 = "Takeout/Google Photos/Photos from 2013/"
	lib19 = "Takeout/Google Photos/Photos from 2019/"
	lib20 = "Takeout/Google Photos/Photos from 2020/"
	trip  = "Takeout/Google Photos/Summer trip/"
	trash = "Takeout/Google Photos/Trash/"
)

type jobEnv struct {
	app   *tests.TestApp
	r     *Runner
	alice *core.Record
}

func newJobEnv(t *testing.T) *jobEnv {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	media.Register(app)
	albums.Register(app)
	alice, _ := testutil.User(t, app, "alice@test.local")
	return &jobEnv{app: app, r: NewRunner(app), alice: alice}
}

// takeoutZip writes a small export in the server's import folder: a photo without EXIF date (Google gives
// it), one with EXIF, the same first photo in an album, a trashed one and one without JSON.
func (e *jobEnv) takeoutZip(t *testing.T, name string) {
	t.Helper()
	scan := mediatest.JPEG(mediatest.Photo{Width: 40, Height: 30})
	exif := mediatest.JPEG(mediatest.Photo{Width: 41, Height: 30, Taken: time.Date(2019, 5, 1, 10, 0, 0, 0, time.UTC)})
	writeZip(t, filepath.Join(e.app.DataDir(), ServerDir, name),
		zipFile{name: lib13 + "scan.jpg", data: scan, store: true},
		named(lib13+"scan.jpg.supplemental-metadata.json", js(`{"title":"scan.jpg","description":"Grandma","photoTakenTime":{"timestamp":"1373803200"},"geoData":{"latitude":43.29,"longitude":5.37},"favorited":true}`)),
		zipFile{name: lib19 + "exif.jpg", data: exif, store: true},
		named(lib19+"exif.jpg.json", js(`{"photoTakenTime":{"timestamp":"1556877600"}}`)),
		zipFile{name: trip + "scan.jpg", data: scan, store: true},
		named(trip+"scan.jpg.json", js(`{"photoTakenTime":{"timestamp":"1373803200"}}`)),
		named(trip+"metadata.json", js(`{"title":"Summer trip"}`)),
		zipFile{name: trash + "gone.jpg", data: mediatest.JPEG(mediatest.Photo{Width: 42, Height: 30}), store: true},
		named(trash+"gone.jpg.json", js(`{"photoTakenTime":{"timestamp":"1373803200"},"trashed":true}`)),
		zipFile{name: lib20 + "nojson.jpg", data: mediatest.JPEG(mediatest.Photo{Width: 43, Height: 30}), store: true},
	)
}

func (e *jobEnv) job(t *testing.T, source string, files ...string) *core.Record {
	t.Helper()
	col, err := e.app.FindCollectionByNameOrId(Collection)
	if err != nil {
		t.Fatal(err)
	}
	j := core.NewRecord(col)
	j.Set("owner", e.alice.Id)
	j.Set("created_by", e.alice.Id)
	j.Set("source", source)
	j.Set("files", files)
	j.Set("status", StatusQueued)
	if err := e.app.Save(j); err != nil {
		t.Fatal(err)
	}
	return j
}

// runOne runs the next queued job synchronously and returns it reloaded.
func (e *jobEnv) runOne(t *testing.T) *core.Record {
	t.Helper()
	j := e.r.next()
	if j == nil {
		t.Fatal("no queued job")
	}
	e.r.run(j)
	j, err := e.app.FindRecordById(Collection, j.Id)
	if err != nil {
		t.Fatal(err)
	}
	return j
}

func counts(j *core.Record) map[string]int {
	out := map[string]int{}
	for _, f := range []string{"total", "processed", "imported", "duplicates", "skipped", "undated", "failed", "albums"} {
		out[f] = j.GetInt(f)
	}
	return out
}

func wantCounts(t *testing.T, j *core.Record, want map[string]int) {
	t.Helper()
	got := counts(j)
	for k, v := range want {
		if got[k] != v {
			t.Errorf("%s = %d, want %d (all: %v, error %q)", k, got[k], v, got, j.GetString("error"))
		}
	}
}

func (e *jobEnv) mediaOf(t *testing.T, name string) *core.Record {
	t.Helper()
	node, err := e.app.FindFirstRecordByFilter(drive.Collection, "owner = {:o} && name = {:n}", dbx.Params{"o": e.alice.Id, "n": name})
	if err != nil {
		t.Fatalf("node %s: %v", name, err)
	}
	m, err := e.app.FindFirstRecordByData(media.Collection, "node", node.Id)
	if err != nil {
		t.Fatalf("media of %s: %v", name, err)
	}
	return m
}

func TestImportFromServerFolder(t *testing.T) {
	e := newJobEnv(t)
	e.takeoutZip(t, "takeout.zip")
	e.job(t, "server", "takeout.zip")
	j := e.runOne(t)
	if j.GetString("status") != StatusDone {
		t.Fatalf("status = %s (%s)", j.GetString("status"), j.GetString("error"))
	}
	wantCounts(t, j, map[string]int{"total": 5, "processed": 5, "imported": 3, "duplicates": 1, "skipped": 1, "undated": 1, "failed": 0, "albums": 1})

	scan := e.mediaOf(t, "scan.jpg")
	if got := scan.GetDateTime("taken_at").Time(); !got.Equal(time.Unix(1373803200, 0)) {
		t.Errorf("taken_at = %v", got)
	}
	if !scan.GetBool("has_location") || scan.GetFloat("lat") != 43.29 || !scan.GetBool("favorite") || scan.GetString("description") != "Grandma" {
		t.Errorf("metadata not restored: %v", scan.PublicExport())
	}
	// One file, in Photos/Google Photos/2013, also in the album.
	node, _ := e.app.FindRecordById(drive.Collection, scan.GetString("node"))
	parent, _ := e.app.FindRecordById(drive.Collection, node.GetString("parent"))
	root, _ := e.app.FindRecordById(drive.Collection, parent.GetString("parent"))
	photos, _ := e.app.FindRecordById(drive.Collection, root.GetString("parent"))
	if parent.GetString("name") != "2013" || root.GetString("name") != RootFolder ||
		photos == nil || photos.GetString("name") != drive.PhotosFolder || photos.GetString("parent") != "" {
		t.Errorf("folder = %s/%s", root.GetString("name"), parent.GetString("name"))
	}
	album, err := e.app.FindFirstRecordByData(albums.Collection, "name", "Summer trip")
	if err != nil {
		t.Fatal(err)
	}
	if n, _ := e.app.CountRecords(albums.Items, dbx.HashExp{"album": album.Id, "media": scan.Id}); n != 1 {
		t.Errorf("album items = %d", n)
	}
	if n, _ := e.app.CountRecords(drive.Collection, dbx.HashExp{"owner": e.alice.Id, "kind": drive.KindFile}); n != 3 {
		t.Errorf("files = %d, want 3 (trashed photo skipped, album copy deduplicated)", n)
	}

	// The media worker keeps the imported values when the file has none, and prefers a plausible EXIF date.
	if err := media.Process(e.app, scan.Id); err != nil {
		t.Fatal(err)
	}
	scan, _ = e.app.FindRecordById(media.Collection, scan.Id)
	if got := scan.GetDateTime("taken_at").Time(); scan.GetString("status") != "ready" || !got.Equal(time.Unix(1373803200, 0)) || !scan.GetBool("has_location") {
		t.Errorf("after processing: status %s, taken_at %v, located %v", scan.GetString("status"), got, scan.GetBool("has_location"))
	}
	exif := e.mediaOf(t, "exif.jpg")
	if err := media.Process(e.app, exif.Id); err != nil {
		t.Fatal(err)
	}
	exif, _ = e.app.FindRecordById(media.Collection, exif.Id)
	if got := exif.GetDateTime("taken_at").Time(); got.Format("2006-01-02") != "2019-05-01" {
		t.Errorf("EXIF date must win: %v", got)
	}

	// Re-running is safe: everything is already there.
	e.job(t, "server", "takeout.zip")
	j = e.runOne(t)
	wantCounts(t, j, map[string]int{"imported": 0, "duplicates": 4, "skipped": 1})
	if n, _ := e.app.CountRecords(albums.Collection, dbx.HashExp{"owner": e.alice.Id}); n != 1 {
		t.Errorf("albums = %d, want the same album reused", n)
	}
	// Server files are never deleted.
	if _, err := os.Stat(filepath.Join(e.app.DataDir(), ServerDir, "takeout.zip")); err != nil {
		t.Error("server archive deleted")
	}
}

func TestImportResumesFromProgress(t *testing.T) {
	e := newJobEnv(t)
	e.takeoutZip(t, "takeout.zip")
	j := e.job(t, "server", "takeout.zip")
	// A restart interrupted it after the first two items (library order: scan.jpg, exif.jpg).
	j.Set("status", StatusRunning)
	j.Set("progress", progress{Cursor: 1, Ahead: []int{2}})
	j.Set("processed", 2)
	j.Set("imported", 2)
	if err := e.app.Save(j); err != nil {
		t.Fatal(err)
	}
	e.r.Start()
	deadline := time.Now().Add(10 * time.Second)
	for {
		j, _ = e.app.FindRecordById(Collection, j.Id)
		if j.GetString("status") == StatusDone || time.Now().After(deadline) {
			break
		}
		time.Sleep(20 * time.Millisecond)
	}
	e.r.Stop()
	if j.GetString("status") != StatusDone {
		t.Fatalf("status = %s", j.GetString("status"))
	}
	wantCounts(t, j, map[string]int{"processed": 5})
	// Item 0 (scan.jpg) and 2 were "done": the album copy of scan.jpg is the only scan.jpg imported.
	if n, _ := e.app.CountRecords(drive.Collection, dbx.HashExp{"owner": e.alice.Id, "name": "exif.jpg"}); n != 1 {
		t.Errorf("exif.jpg imported %d times", n)
	}
}

func TestImportCancelAndCleanup(t *testing.T) {
	e := newJobEnv(t)
	dir := filepath.Join(e.app.DataDir(), UploadDir, e.alice.Id)
	writeZip(t, filepath.Join(dir, "abc.zip"), zipFile{name: lib20 + "a.jpg", data: mediatest.JPEG(mediatest.Photo{Width: 10, Height: 10}), store: true})

	// Cancelled while queued: nothing is imported, the upload is kept for a new job.
	j := e.job(t, "upload", "abc")
	if ok, err := e.r.Cancel(j.Id); !ok || err != nil {
		t.Fatalf("cancel: %v %v", ok, err)
	}
	j, _ = e.app.FindRecordById(Collection, j.Id)
	if j.GetString("status") != StatusCancelled {
		t.Errorf("status = %s", j.GetString("status"))
	}
	if _, err := os.Stat(filepath.Join(dir, "abc.zip")); err != nil {
		t.Error("uploaded archive deleted after cancel")
	}
	if ok, _ := e.r.Cancel(j.Id); ok {
		t.Error("a finished job was cancelled again")
	}

	// Cancelled while running.
	writeZip(t, filepath.Join(dir, "def.zip"), zipFile{name: lib20 + "a.jpg", data: []byte("x"), store: true})
	e.job(t, "upload", "def")
	running := e.r.next()
	if ok, _ := e.r.Cancel(running.Id); !ok {
		t.Fatal("running job not cancellable")
	}
	e.r.run(running)
	running, _ = e.app.FindRecordById(Collection, running.Id)
	if running.GetString("status") != StatusCancelled || running.GetInt("imported") != 0 {
		t.Errorf("status = %s, imported %d", running.GetString("status"), running.GetInt("imported"))
	}
	if _, err := os.Stat(filepath.Join(dir, "def.zip")); err != nil {
		t.Error("uploaded archive deleted after cancel")
	}

	// A successful import deletes its archives.
	e.job(t, "upload", "abc")
	if j := e.runOne(t); j.GetString("status") != StatusDone {
		t.Fatalf("status = %s (%s)", j.GetString("status"), j.GetString("error"))
	}
	if _, err := os.Stat(filepath.Join(dir, "abc.zip")); !os.IsNotExist(err) {
		t.Error("uploaded archive kept after a successful import")
	}
	if entries, _ := os.ReadDir(filepath.Join(e.app.DataDir(), workDir)); len(entries) != 0 {
		t.Errorf("temp files left: %v", entries)
	}
}

func TestImportStopsWhenQuotaIsFull(t *testing.T) {
	e := newJobEnv(t)
	e.alice.Set("quota_bytes", 1) // smaller than any photo
	if err := e.app.Save(e.alice); err != nil {
		t.Fatal(err)
	}
	e.takeoutZip(t, "takeout.zip")
	e.job(t, "server", "takeout.zip")
	j := e.runOne(t)
	if j.GetString("status") != StatusFailed || j.GetString("error") != "quota_exceeded" {
		t.Errorf("status = %s, error = %q", j.GetString("status"), j.GetString("error"))
	}
	if j.GetInt("imported") != 0 {
		t.Errorf("imported = %d", j.GetInt("imported"))
	}
}

func TestImportReportsFailuresAndBadArchives(t *testing.T) {
	e := newJobEnv(t)
	// Not a zip at all.
	if err := os.MkdirAll(filepath.Join(e.app.DataDir(), ServerDir), 0o750); err != nil {
		t.Fatal(err)
	}
	if err := os.WriteFile(filepath.Join(e.app.DataDir(), ServerDir, "broken.zip"), []byte("nope"), 0o600); err != nil {
		t.Fatal(err)
	}
	e.job(t, "server", "broken.zip")
	if j := e.runOne(t); j.GetString("error") != "unreadable" {
		t.Errorf("broken archive: %s %q", j.GetString("status"), j.GetString("error"))
	}
	// No photos.
	writeZip(t, filepath.Join(e.app.DataDir(), ServerDir, "empty.zip"), named("Takeout/readme.html", zipFile{data: []byte("x")}))
	e.job(t, "server", "empty.zip")
	if j := e.runOne(t); j.GetString("error") != "no_photos" {
		t.Errorf("empty: %q", j.GetString("error"))
	}
}

func TestPlausibleTaken(t *testing.T) {
	now := time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)
	google := time.Date(2013, 7, 14, 12, 0, 0, 0, time.UTC)
	for _, tt := range []struct {
		own  time.Time
		want bool
	}{
		{time.Time{}, false},
		{time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC), false},
		{time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC), false},
		{time.Date(2000, 1, 1, 0, 0, 0, 0, time.UTC), false}, // reset camera clock
		{time.Date(2013, 1, 1, 0, 0, 0, 0, time.UTC), false},
		{time.Date(2013, 7, 14, 14, 0, 0, 0, time.UTC), true}, // timezone difference: EXIF kept
		{time.Date(2012, 3, 4, 5, 6, 7, 0, time.UTC), true},
	} {
		if got := media.PlausibleTaken(tt.own, google, now); got != tt.want {
			t.Errorf("PlausibleTaken(%v) = %v, want %v", tt.own, got, tt.want)
		}
	}
}
