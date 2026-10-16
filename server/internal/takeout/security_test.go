package takeout

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"sync/atomic"
	"testing"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

// emptyEntries builds an archive of n empty entries (the shape of a central-directory bomb).
func emptyEntries(t *testing.T, path string, n int) {
	t.Helper()
	files := make([]zipFile, n)
	for i := range files {
		files[i] = zipFile{name: fmt.Sprintf("e%d", i), store: true}
	}
	writeZip(t, path, files...)
}

func openErr(t *testing.T, dir, name string) error {
	t.Helper()
	root, err := os.OpenRoot(dir)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = root.Close() }()
	a, err := openSources(root, []string{name})
	if err == nil {
		a.Close()
	}
	return err
}

func setLimit[T any](t *testing.T, v *T, to T) {
	old := *v
	*v = to
	t.Cleanup(func() { *v = old })
}

func TestCentralDirectoryLimits(t *testing.T) {
	dir := t.TempDir()
	emptyEntries(t, filepath.Join(dir, "many.zip"), 50)
	setLimit(t, &maxEntriesPerArchive, 20)
	if err := openErr(t, dir, "many.zip"); !errors.Is(err, errTooManyEntries) {
		t.Errorf("entries over the limit: %v", err)
	}

	// The end record lies (1 record): what archive/zip reads is what counts.
	b, _ := os.ReadFile(filepath.Join(dir, "many.zip"))
	i := bytes.LastIndex(b, []byte("PK\x05\x06"))
	binary.LittleEndian.PutUint16(b[i+8:], 1)
	binary.LittleEndian.PutUint16(b[i+10:], 1)
	if err := os.WriteFile(filepath.Join(dir, "lying.zip"), b, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := openErr(t, dir, "lying.zip"); err == nil {
		t.Error("lying record count accepted")
	}

	setLimit(t, &maxEntriesPerArchive, 1000)
	setLimit(t, &maxCentralDir, 512)
	setLimit(t, &dirReadSlack, 0)
	if err := openErr(t, dir, "many.zip"); !errors.Is(err, errUnsafe) {
		t.Errorf("central directory over its read budget: %v", err)
	}

	// Several archives share the job's limit.
	setLimit(t, &maxCentralDir, 48<<20)
	setLimit(t, &maxEntries, 60)
	emptyEntries(t, filepath.Join(dir, "more.zip"), 50)
	root, _ := os.OpenRoot(dir)
	defer func() { _ = root.Close() }()
	if _, err := openSources(root, []string{"many.zip", "more.zip"}); !errors.Is(err, errTooManyEntries) {
		t.Errorf("cumulative limit: %v", err)
	}
}

// crafted rebuilds an archive of n entries with a plain (non-ZIP64) end record whose directory size and
// offset are shifted, the way a hostile archive steers where archive/zip starts reading.
func crafted(t *testing.T, n int, sizeDelta, offDelta int64, locator bool) []byte {
	t.Helper()
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	for i := range n {
		f, _ := w.CreateHeader(&zip.FileHeader{Name: fmt.Sprint(i), Method: zip.Store})
		_, _ = f.Write([]byte("x"))
	}
	_ = w.Close()
	d := buf.Bytes()
	le := binary.LittleEndian
	var size, off uint64
	if p := bytes.LastIndex(d, []byte("PK\x06\x06")); p >= 0 { // drop the ZIP64 records
		size, off = le.Uint64(d[p+40:]), le.Uint64(d[p+48:])
		d = d[:p]
	} else {
		p := bytes.LastIndex(d, []byte("PK\x05\x06"))
		size, off = uint64(le.Uint32(d[p+12:])), uint64(le.Uint32(d[p+16:]))
		d = d[:p]
	}
	d = append([]byte{}, d...)
	if locator { // a ZIP64 locator archive/zip ignores (disk number 1)
		loc := make([]byte, 20)
		copy(loc, "PK\x06\x07")
		le.PutUint32(loc[4:], 1)
		d = append(d, loc...)
	}
	e := make([]byte, 22)
	copy(e, "PK\x05\x06")
	records := uint16(n) // #nosec G115 -- archive/zip compares the low 16 bits too
	le.PutUint16(e[8:], records)
	le.PutUint16(e[10:], records)
	le.PutUint32(e[12:], uint32(int64(size)+sizeDelta))
	le.PutUint32(e[16:], uint32(int64(off)+offDelta))
	return append(d, e...)
}

func TestCraftedEndRecords(t *testing.T) {
	dir := t.TempDir()
	write := func(name string, b []byte) {
		if err := os.WriteFile(filepath.Join(dir, name), b, 0o600); err != nil {
			t.Fatal(err)
		}
	}
	// Each steers archive/zip differently from a naive reading of the end record; all must be
	// bounded by what archive/zip actually reads.
	write("negative-base.zip", crafted(t, 300, 0, 1, false))
	write("positive-base.zip", crafted(t, 300, -7, 0, false))
	for _, name := range []string{"negative-base.zip", "positive-base.zip"} {
		b, _ := os.ReadFile(filepath.Join(dir, name))
		if zr, err := zip.NewReader(bytes.NewReader(b), int64(len(b))); err != nil || len(zr.File) < 300 {
			t.Fatalf("%s is not read by archive/zip as crafted: %v", name, err)
		}
	}
	setLimit(t, &maxEntriesPerArchive, 100)
	for _, name := range []string{"negative-base.zip", "positive-base.zip"} {
		if err := openErr(t, dir, name); err == nil {
			t.Errorf("%s: %d entries accepted over a limit of 100", name, 300)
		}
	}
	// The same reads stay within a small read budget: no unbounded allocation.
	setLimit(t, &maxEntriesPerArchive, 100_000)
	setLimit(t, &maxCentralDir, 4<<10)
	setLimit(t, &dirReadSlack, 0)
	for _, name := range []string{"negative-base.zip", "positive-base.zip"} {
		if err := openErr(t, dir, name); !errors.Is(err, errUnsafe) {
			t.Errorf("%s over the read budget: %v", name, err)
		}
	}
}

func TestEntryCountEdgeCases(t *testing.T) {
	if testing.Short() {
		t.Skip("builds 65 535- and 70 000-entry archives")
	}
	dir := t.TempDir()
	// Exactly 65 535 entries in a plain archive (record count 0xffff, no ZIP64 records) is valid.
	if err := os.WriteFile(filepath.Join(dir, "65535.zip"), crafted(t, 65_535, 0, 0, false), 0o600); err != nil {
		t.Fatal(err)
	}
	setLimit(t, &maxEntriesPerArchive, 100_000)
	if err := openErr(t, dir, "65535.zip"); err != nil {
		t.Errorf("65 535 entries refused: %v", err)
	}
	// The same with a ZIP64 locator archive/zip ignores (disk number 1): it reads the 65 535 entries.
	if err := os.WriteFile(filepath.Join(dir, "bad-locator.zip"), crafted(t, 65_535, 0, 0, true), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := openErr(t, dir, "bad-locator.zip"); err != nil {
		t.Errorf("65 535 entries with an ignored locator refused: %v", err)
	}
	setLimit(t, &maxEntriesPerArchive, 1000)
	if err := openErr(t, dir, "bad-locator.zip"); !errors.Is(err, errTooManyEntries) {
		t.Errorf("ignored locator over the limit: %v", err)
	}
	setLimit(t, &maxCentralDir, 64<<10)
	setLimit(t, &dirReadSlack, 0)
	if err := openErr(t, dir, "bad-locator.zip"); !errors.Is(err, errUnsafe) {
		t.Errorf("ignored locator over the read budget: %v", err)
	}
	setLimit(t, &maxCentralDir, 48<<20)
	setLimit(t, &dirReadSlack, 256<<10)
	setLimit(t, &maxEntriesPerArchive, 100_000)
	emptyEntries(t, filepath.Join(dir, "z64.zip"), 70_000) // real ZIP64 end records
	if err := openErr(t, dir, "z64.zip"); err != nil {
		t.Errorf("valid ZIP64 refused: %v", err)
	}
	setLimit(t, &maxEntriesPerArchive, 1000)
	if err := openErr(t, dir, "z64.zip"); !errors.Is(err, errTooManyEntries) {
		t.Errorf("ZIP64 over the limit: %v", err)
	}
}

func TestOverlappingEntriesRefused(t *testing.T) {
	dir := t.TempDir()
	writeZip(t, filepath.Join(dir, "o.zip"),
		zipFile{name: "a.jpg", data: bytes.Repeat([]byte("a"), 100)},
		zipFile{name: "b.jpg", data: bytes.Repeat([]byte("b"), 100)})
	b, _ := os.ReadFile(filepath.Join(dir, "o.zip"))
	first := bytes.Index(b, []byte("PK\x01\x02"))
	second := first + 1 + bytes.Index(b[first+1:], []byte("PK\x01\x02"))
	copy(b[second+42:second+46], b[first+42:first+46]) // both entries point at the same data
	if err := os.WriteFile(filepath.Join(dir, "o.zip"), b, 0o600); err != nil {
		t.Fatal(err)
	}
	if err := openErr(t, dir, "o.zip"); !errors.Is(err, errUnsafe) {
		t.Errorf("overlapping entries: %v", err)
	}
}

func TestBudgetAndCancelStopReads(t *testing.T) {
	dir := t.TempDir()
	writeZip(t, filepath.Join(dir, "t.zip"), zipFile{name: "a.jpg", data: bytes.Repeat([]byte("x"), 1000)})
	a := openTest(t, dir, "t.zip")
	entries, _ := a.entries(context.Background())
	a.budget = &atomic.Int64{}
	a.budget.Store(10)
	if _, err := a.copyEntry(context.Background(), entries[0], io.Discard); !errors.Is(err, errBudget) {
		t.Errorf("budget: %v", err)
	}
	a.budget = nil
	ctx, cancel := context.WithCancel(context.Background())
	cancel()
	if _, err := a.copyEntry(ctx, entries[0], io.Discard); !errors.Is(err, context.Canceled) {
		t.Errorf("cancelled copy: %v", err)
	}
	if _, err := buildPlan(ctx, entries, nil, time.Now()); !errors.Is(err, context.Canceled) {
		t.Errorf("cancelled plan: %v", err)
	}
}

func TestHardLinksAndFormatCharacters(t *testing.T) {
	dir := t.TempDir()
	lib := filepath.Join(dir, "x", "Photos from 2020")
	if err := os.MkdirAll(lib, 0o750); err != nil {
		t.Fatal(err)
	}
	outside := filepath.Join(t.TempDir(), "secret.jpg")
	if err := os.WriteFile(outside, []byte("secret"), 0o600); err != nil {
		t.Fatal(err)
	}
	if err := os.Link(outside, filepath.Join(lib, "link.jpg")); err != nil {
		t.Skip("hard links unsupported here:", err)
	}
	if err := os.WriteFile(filepath.Join(lib, "ok.jpg"), []byte("ok"), 0o600); err != nil {
		t.Fatal(err)
	}
	a := openTest(t, dir, "x")
	entries, _ := a.entries(context.Background())
	if len(entries) != 1 || entries[0].name() != "ok.jpg" {
		t.Errorf("entries = %+v (hard links must be skipped)", entries)
	}
	if _, err := a.open(entry{src: 0, path: "Photos from 2020/link.jpg", size: 6}); err == nil {
		t.Error("hard link opened")
	}

	if got, ok := cleanEntryPath("a/b\u202egpj.exe"); !ok || got != "a/b_gpj.exe" {
		t.Errorf("bidi override: %q %v", got, ok)
	}
	if _, ok := cleanEntryPath("a\u0085.jpg"); ok {
		t.Error("C1 control accepted")
	}
	if got := nodeName("x\u200fy.jpg"); got != "x_y.jpg" {
		t.Errorf("nodeName = %q", got)
	}
	if got := cleanText("a\u202eb\u2066c", 100); got != "abc" {
		t.Errorf("cleanText = %q", got)
	}
}

func TestSaturatingSums(t *testing.T) {
	if satAdd(1<<62, 1<<62) != 1<<63-1 || satMul(1<<40, 1<<40) != 1<<63-1 || satAdd(2, 3) != 5 {
		t.Error("saturation")
	}
	it := item{entry: entry{size: drive.MaxFileSize + 1}}
	if yearOf(it) != 0 {
		t.Error("year of an undated item")
	}
	it.meta.Taken = time.Date(2019, 12, 31, 23, 30, 0, 0, time.UTC)
	if got := yearOf(it); got != it.meta.Taken.In(time.Local).Year() {
		t.Errorf("year in the server's zone = %d", got)
	}
	it.year = 2018
	if yearOf(it) != 2018 {
		t.Error("Takeout's folder year must win")
	}
}

func TestFailuresStayBounded(t *testing.T) {
	e := newJobEnv(t)
	long := strings.Repeat("<&>", 90) // escaped in JSON: six bytes each
	var files []zipFile
	for i := range 400 {
		files = append(files, zipFile{name: fmt.Sprintf("Takeout/%s/Photos from 2020/%s%03d.jpg", long, long, i), data: []byte("not a photo"), store: true})
	}
	writeZip(t, filepath.Join(e.app.DataDir(), ServerDir, "f.zip"), files...)
	e.job(t, "server", "f.zip")
	j := e.runOne(t)
	if j.GetString("status") != StatusDone || j.GetInt("failed") != 400 {
		t.Fatalf("status %s, failed %d", j.GetString("status"), j.GetInt("failed"))
	}
	b, _ := json.Marshal(j.Get("failures"))
	var list []map[string]string
	_ = json.Unmarshal(b, &list)
	if len(b) > maxFailuresBytes || len(list) == 0 || len(list) == 400 {
		t.Errorf("failures: %d bytes, %d items", len(b), len(list))
	}
	if list[0]["reason"] != "unsupported" || len([]rune(list[0]["path"])) > maxFailurePath {
		t.Errorf("first failure = %v", list[0])
	}
}

func TestRestartsStopACrashingJob(t *testing.T) {
	e := newJobEnv(t)
	j := e.job(t, "server", "missing.zip")
	j.Set("status", StatusScanning)
	j.Set("attempts", maxAttempts-1)
	if err := e.app.Save(j); err != nil {
		t.Fatal(err)
	}
	e.r.Start()
	e.r.Stop()
	j, _ = e.app.FindRecordById(Collection, j.Id)
	if j.GetString("status") != StatusFailed || j.GetString("error") != "interrupted" {
		t.Errorf("status %s, error %q", j.GetString("status"), j.GetString("error"))
	}
}

func TestCleanShutdownIsNotAnAttempt(t *testing.T) {
	e := newJobEnv(t)
	e.takeoutZip(t, "takeout.zip")
	j := e.job(t, "server", "takeout.zip")
	claimed := e.r.next()
	e.r.stop() // the server stops (an update) while the job runs
	e.r.run(claimed)
	j, _ = e.app.FindRecordById(Collection, j.Id)
	if j.GetString("status") != StatusQueued || j.GetInt("attempts") != 0 {
		t.Errorf("status %s, attempts %d", j.GetString("status"), j.GetInt("attempts"))
	}
}

func TestUnusedUploadsCleanup(t *testing.T) {
	e := newJobEnv(t)
	dir := uploadsOf(e.app, e.alice.Id)
	old := time.Now().Add(-48 * time.Hour)
	for _, id := range []string{"aaa", "bbb", "ccc"} {
		writeZip(t, filepath.Join(dir, id+".zip"), zipFile{name: "x", data: []byte("x")})
		_ = os.Chtimes(filepath.Join(dir, id+".zip"), old, old)
	}
	e.job(t, "upload", "ccc") // used by an unfinished job
	// A recent archive keeps the older ones (the user is still sending the export).
	writeZip(t, filepath.Join(dir, "ddd.zip"), zipFile{name: "x", data: []byte("x")})
	if err := e.r.removeUnusedUploads(time.Now()); err != nil {
		t.Fatal(err)
	}
	if list, _ := ListUploads(e.app, e.alice.Id); len(list) != 4 {
		t.Fatalf("kept %d archives, want 4 while uploads are recent", len(list))
	}
	if err := e.r.removeUnusedUploads(time.Now().Add(48 * time.Hour)); err != nil {
		t.Fatal(err)
	}
	list, _ := ListUploads(e.app, e.alice.Id)
	if len(list) != 1 || list[0].ID != "ccc" {
		t.Errorf("left %+v, want only the archive a job uses", list)
	}
}

func TestDiskNeedCountsEachContentOnce(t *testing.T) {
	e := newJobEnv(t)
	dir := t.TempDir()
	photo := bytes.Repeat([]byte("p"), 1000)
	writeZip(t, filepath.Join(dir, "t.zip"),
		zipFile{name: lib13 + "a.jpg", data: photo, store: true},
		zipFile{name: trip + "a.jpg", data: photo, store: true})
	a := openTest(t, dir, "t.zip")
	entries, _ := a.entries(context.Background())
	items := []item{{entry: entries[0]}, {entry: entries[1]}, {entry: entry{path: "x", size: 1 << 50}, meta: Meta{Trashed: true}}}
	if items[0].contentKey() != items[1].contentKey() {
		t.Fatal("album copy has another content key")
	}
	// 1000 bytes, not 2000, and never the trashed petabyte.
	if err := e.r.checkDisk(items, &progress{}); err != nil {
		t.Errorf("checkDisk: %v", err)
	}
}

func TestDuplicateGetsGoogleFavoriteAndDescription(t *testing.T) {
	e := newJobEnv(t)
	photo := mediatest.JPEG(mediatest.Photo{Width: 44, Height: 30})
	// Backed up from the phone before the import.
	n := testutil.Node(t, e.app, e.alice, "", "IMG_1.jpg", drive.KindFile)
	f, _ := filesystem.NewFileFromBytes(photo, "IMG_1.jpg")
	n.Set("blob", f)
	if err := e.app.Save(n); err != nil {
		t.Fatal(err)
	}
	writeZip(t, filepath.Join(e.app.DataDir(), ServerDir, "t.zip"),
		zipFile{name: lib13 + "IMG_1.jpg", data: photo, store: true},
		named(lib13+"IMG_1.jpg.json", js(`{"photoTakenTime":{"timestamp":"1373803200"},"favorited":true,"description":"Beach"}`)))
	e.job(t, "server", "t.zip")
	j := e.runOne(t)
	wantCounts(t, j, map[string]int{"duplicates": 1, "imported": 0})
	m, err := e.app.FindFirstRecordByData(media.Collection, "node", n.Id)
	if err != nil {
		t.Fatal(err)
	}
	if !m.GetBool("favorite") || m.GetString("description") != "Beach" {
		t.Errorf("favorite %v, description %q", m.GetBool("favorite"), m.GetString("description"))
	}
	// Google's date is kept and merged by the worker (the phone's copy had no EXIF date).
	if m.GetDateTime("import_taken_at").Time().Unix() != 1373803200 || m.GetString("status") != "pending" {
		t.Errorf("import_taken_at %v, status %s", m.GetDateTime("import_taken_at"), m.GetString("status"))
	}
	if err := media.Process(e.app, m.Id); err != nil {
		t.Fatal(err)
	}
	m, _ = e.app.FindRecordById(media.Collection, m.Id)
	if m.GetDateTime("taken_at").Time().Unix() != 1373803200 {
		t.Errorf("taken_at after processing = %v", m.GetDateTime("taken_at"))
	}
	// The user's own description is never overwritten.
	m.Set("description", "Mine")
	_ = e.app.Save(m)
	e.job(t, "server", "t.zip")
	e.runOne(t)
	m, _ = e.app.FindRecordById(media.Collection, m.Id)
	if m.GetString("description") != "Mine" {
		t.Errorf("description overwritten: %q", m.GetString("description"))
	}
	if n, _ := e.app.CountRecords(drive.Collection, dbx.HashExp{"owner": e.alice.Id, "kind": drive.KindFile}); n != 1 {
		t.Errorf("%d files", n)
	}
}

// The file is hashed once: drive takes the importer's size and SHA-256.
func TestSaveNewFileKnownSkipsHashing(t *testing.T) {
	e := newJobEnv(t)
	tmp := filepath.Join(t.TempDir(), "a.jpg")
	_ = os.WriteFile(tmp, mediatest.JPEG(mediatest.Photo{Width: 10, Height: 10}), 0o600)
	fake := strings.Repeat("ab", 32)
	node, err := drive.SaveNewFileKnown(e.app, e.alice.Id, "", "a.jpg", func() (*filesystem.File, error) {
		return filesystem.NewFileFromPath(tmp)
	}, 123, fake)
	if err != nil {
		t.Fatal(err)
	}
	if node.GetString("sha256") != fake || node.GetInt("size") != 123 || node.GetString("mime") != "image/jpeg" {
		t.Errorf("node: sha %s size %d mime %s", node.GetString("sha256"), node.GetInt("size"), node.GetString("mime"))
	}
	_ = zip.Store
}

// A 32 GB SD card with 4 GB free: phone backups and drive uploads go on, import archives wait.
func TestDiskFloors(t *testing.T) {
	const gb = 1_000_000_000
	free, total := uint64(4*gb), uint64(32*gb)
	if !fits(free, total, 0, 100<<20, SafetyFloor) {
		t.Error("regular upload refused with 4 GB free")
	}
	if fits(free, total, 0, 100<<20, ImportFloor) {
		t.Error("import upload accepted below the 5 GB floor")
	}
	if SafetyFloor(total) != 512<<20 || SafetyFloor(200*gb) != 2*gb {
		t.Errorf("safety floor = %d, %d", SafetyFloor(total), SafetyFloor(200*gb))
	}
	if ImportFloor(total) != 5*gb || ImportFloor(200*gb) != 10*gb {
		t.Errorf("import floor = %d, %d", ImportFloor(total), ImportFloor(200*gb))
	}
	// Partial uploads count against what is left.
	if fits(free, total, 3*gb+600<<20, 100<<20, SafetyFloor) {
		t.Error("announced partial uploads ignored")
	}
}
