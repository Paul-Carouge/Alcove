// Package takeout imports a Google Photos library from Google Takeout archives (ADR 0030): .zip files
// uploaded with tus or dropped by an administrator in <data dir>/import. Photos become drive files in a
// "Google Photos" folder, their Google metadata goes into the database (never into the files), and the
// album folders become Alcove albums. One job runs at a time; jobs survive restarts.
package takeout

import (
	"context"
	"crypto/sha256"
	"database/sql"
	"encoding/hex"
	"encoding/json"
	"errors"
	"io"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"slices"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"

	"github.com/gabriel-vasile/mimetype"
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/albums"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
)

const (
	Collection = "imports"
	// RootFolder receives the photos, by year ("Google Photos/2019"). Google's product name: not translated.
	RootFolder = "Google Photos"

	ServerDir = "import"         // <data dir>/import: archives dropped by an administrator
	UploadDir = "import-uploads" // <data dir>/import-uploads/<owner>/<upload id>.zip
	workDir   = "import-work"    // one temp file per entry being imported

	StatusQueued    = "queued"
	StatusScanning  = "scanning"
	StatusRunning   = "running"
	StatusDone      = "done"
	StatusFailed    = "failed"
	StatusCancelled = "cancelled"

	maxFailures = 1000
	// maxFailuresBytes keeps the failures list well under its 1 MiB field (paths are escaped in JSON).
	maxFailuresBytes = 512 << 10
	maxFailurePath   = 300
	// maxAttempts: a job interrupted this many times by restarts (a crash while reading it, say) fails
	// instead of crashing the server again.
	maxAttempts = 3
	// maxPendingMedia: the importer waits while the media worker is this far behind, so its queue
	// never overflows (overflowing records wait for the next restart).
	maxPendingMedia = 1000
	saveEvery       = 500 * time.Millisecond
)

// Active statuses: the job is not finished.
var Active = []string{StatusQueued, StatusScanning, StatusRunning}

// Job errors (stored in imports.error, translated by clients).
var (
	errCancelled = errors.New("cancelled")
	errQuota     = jobError("quota_exceeded")
	errDisk      = jobError("disk_full")
	errNoPhotos  = jobError("no_photos")
	errArchives  = jobError("unreadable")
	errEntries   = jobError("too_many_entries")
	errUnsafeJob = jobError("unsafe_archive")
	errRestarts  = jobError("interrupted")
)

// jobErrorOf maps archive errors to job errors.
func jobErrorOf(err error) error {
	switch {
	case errors.Is(err, errTooManyEntries):
		return errEntries
	case errors.Is(err, errUnsafe), errors.Is(err, errBudget):
		return errUnsafeJob
	}
	return err
}

type jobError string

func (e jobError) Error() string { return string(e) }

// Runner runs the import jobs, one at a time.
type Runner struct {
	app     core.App
	ctx     context.Context
	stop    context.CancelFunc
	wake    chan struct{}
	wg      sync.WaitGroup
	mu      sync.Mutex
	current string
	cancel  context.CancelCauseFunc
	jobCtx  context.Context
	// Workers is the number of entries imported in parallel.
	Workers int
}

// NewRunner returns a stopped runner.
func NewRunner(app core.App) *Runner {
	ctx, stop := context.WithCancel(context.Background())
	return &Runner{app: app, ctx: ctx, stop: stop, wake: make(chan struct{}, 1),
		Workers: min(2, max(1, runtime.NumCPU()/2))}
}

// Register binds the routes, the runner and the cleanup of unused uploads.
func Register(app core.App) *Runner {
	r := NewRunner(app)
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		r.routes(se)
		r.Start()
		return se.Next()
	})
	app.OnTerminate().BindFunc(func(e *core.TerminateEvent) error {
		r.Stop()
		return e.Next()
	})
	app.Cron().MustAdd("alcoveImportUploads", "41 * * * *", func() {
		if err := r.removeUnusedUploads(time.Now()); err != nil {
			app.Logger().Error("cleanup of import uploads failed", "error", err)
		}
	})
	return r
}

// Start resumes the jobs a restart interrupted and starts the loop.
func (r *Runner) Start() {
	_ = os.RemoveAll(filepath.Join(r.app.DataDir(), workDir)) // no job runs yet
	jobs, err := r.app.FindAllRecords(Collection, dbx.In("status", StatusScanning, StatusRunning))
	if err == nil {
		for _, j := range jobs {
			attempts := j.GetInt("attempts") + 1
			if attempts >= maxAttempts {
				r.finish(j, StatusFailed, string(errRestarts))
				continue
			}
			j.Set("attempts", attempts)
			j.Set("status", StatusQueued)
			if err := r.app.Save(j); err != nil {
				r.app.Logger().Error("cannot requeue import", "import", j.Id, "error", err)
			}
		}
	}
	r.wg.Add(1)
	go r.loop()
}

// Stop interrupts the running job (it resumes at the next start) and waits for it.
func (r *Runner) Stop() {
	r.stop()
	r.wg.Wait()
}

// Wake makes the loop look for a queued job now.
func (r *Runner) Wake() {
	select {
	case r.wake <- struct{}{}:
	default:
	}
}

func (r *Runner) loop() {
	defer r.wg.Done()
	for {
		if job := r.next(); job != nil {
			r.run(job)
			continue
		}
		select {
		case <-r.ctx.Done():
			return
		case <-r.wake:
		case <-time.After(time.Minute):
		}
	}
}

// next claims the oldest queued job.
func (r *Runner) next() *core.Record {
	if r.ctx.Err() != nil {
		return nil
	}
	r.mu.Lock()
	defer r.mu.Unlock()
	jobs, err := r.app.FindRecordsByFilter(Collection, "status = 'queued'", "created", 1, 0)
	if err != nil || len(jobs) == 0 {
		return nil
	}
	ctx, cancel := context.WithCancelCause(r.ctx)
	r.current, r.cancel = jobs[0].Id, cancel
	jobs[0].Set("status", StatusScanning)
	if jobs[0].GetDateTime("started_at").IsZero() {
		jobs[0].Set("started_at", time.Now().UTC())
	}
	if err := r.app.Save(jobs[0]); err != nil {
		r.current, r.cancel = "", nil
		cancel(nil)
		return nil
	}
	r.jobCtx = ctx
	return jobs[0]
}

// Cancel stops a job. It reports false when the job has already finished.
func (r *Runner) Cancel(id string) (bool, error) {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.current == id && r.cancel != nil {
		r.cancel(errCancelled)
		return true, nil
	}
	job, err := r.app.FindRecordById(Collection, id)
	if err != nil {
		return false, err
	}
	if !slices.Contains(Active, job.GetString("status")) {
		return false, nil
	}
	r.finish(job, StatusCancelled, "")
	return true, nil
}

func (r *Runner) run(job *core.Record) {
	ctx := r.jobCtx
	err := r.execute(ctx, job)
	r.mu.Lock()
	defer r.mu.Unlock()
	cause := context.Cause(ctx)
	r.cancel(nil)
	r.current, r.cancel, r.jobCtx = "", nil, nil
	switch {
	case errors.Is(cause, errCancelled):
		r.finish(job, StatusCancelled, "")
	case r.ctx.Err() != nil:
		// A clean shutdown (update, restart): back in the queue, not counted as an attempt. Jobs still
		// "running" at the next start were stopped by a crash, and those count.
		job.Set("status", StatusQueued)
		if err := r.app.Save(job); err != nil {
			r.app.Logger().Error("cannot requeue import", "import", job.Id, "error", err)
		}
	case err != nil:
		var je jobError
		code := "internal"
		if errors.As(err, &je) {
			code = string(je)
		} else {
			r.app.Logger().Error("import failed", "import", job.Id, "error", err)
		}
		r.finish(job, StatusFailed, code)
	default:
		r.finish(job, StatusDone, "")
	}
}

// finish records the end of a job. Uploaded archives are deleted only after a successful import: after
// a failure or a cancel they stay (cleaned after a day) so a new job can use them again. Server files
// are never deleted.
func (r *Runner) finish(job *core.Record, status, code string) {
	job.Set("status", status)
	job.Set("error", code)
	job.Set("finished_at", time.Now().UTC())
	if err := r.app.Save(job); err != nil {
		// Never leave a job "running": retry without the bulky fields.
		r.app.Logger().Error("cannot save import", "import", job.Id, "error", err)
		job.Set("failures", []any{})
		job.Set("progress", nil)
		if err := r.app.Save(job); err != nil {
			r.app.Logger().Error("cannot save import", "import", job.Id, "error", err)
		}
	}
	if status == StatusDone && job.GetString("source") == "upload" {
		for _, f := range job.GetStringSlice("files") {
			_ = DeleteUpload(r.app, job.GetString("owner"), f)
		}
	}
}

// progress is the resumable state of a job: every item before cursor is done, plus those in ahead.
type progress struct {
	Cursor int   `json:"cursor"`
	Ahead  []int `json:"ahead,omitempty"`
}

func (p *progress) done(i int) bool { return i < p.Cursor || slices.Contains(p.Ahead, i) }

func (p *progress) mark(i int) {
	p.Ahead = append(p.Ahead, i)
	for {
		k := slices.Index(p.Ahead, p.Cursor)
		if k < 0 {
			return
		}
		p.Ahead = slices.Delete(p.Ahead, k, k+1)
		p.Cursor++
	}
}

type outcome int

const (
	imported outcome = iota
	duplicate
	skipped
	failed
)

type result struct {
	index   int
	outcome outcome
	undated bool
	reason  string
	err     error // stops the job
}

// openArchives opens the job's files, confined to their folder.
func (r *Runner) openArchives(job *core.Record) (*archives, error) {
	dir := filepath.Join(r.app.DataDir(), ServerDir)
	names := job.GetStringSlice("files")
	if job.GetString("source") == "upload" {
		dir = filepath.Join(r.app.DataDir(), UploadDir, job.GetString("owner"))
		for i, n := range names {
			names[i] = n + ".zip"
		}
	}
	root, err := os.OpenRoot(dir)
	if err != nil {
		return nil, errArchives
	}
	defer func() { _ = root.Close() }()
	a, err := openSources(root, names)
	if err != nil {
		r.app.Logger().Warn("cannot open import archives", "import", job.Id, "error", err)
		return nil, errArchives
	}
	return a, nil
}

func (r *Runner) execute(ctx context.Context, job *core.Record) error {
	a, err := r.openArchives(job)
	if err != nil {
		return err
	}
	defer a.Close()
	entries, err := a.entries(ctx)
	if ctx.Err() != nil {
		return ctx.Err()
	}
	if err != nil {
		if je := jobErrorOf(err); !errors.Is(je, err) {
			return je
		}
		return errArchives
	}
	a.setBudget(entries)
	p, err := buildPlan(ctx, entries, func(e entry) (sidecarJSON, error) {
		rc, err := a.open(e)
		if err != nil {
			return sidecarJSON{}, err
		}
		defer func() { _ = rc.Close() }()
		return readJSON(rc)
	}, time.Now())
	if err != nil {
		return jobErrorOf(err)
	}
	if len(p.items) == 0 {
		return errNoPhotos
	}

	var prog progress
	_ = job.UnmarshalJSONField("progress", &prog)
	if err := r.checkDisk(p.items, &prog); err != nil {
		return err
	}
	job.Set("status", StatusRunning)
	job.Set("total", len(p.items))
	if err := r.app.Save(job); err != nil {
		return err
	}

	work := filepath.Join(r.app.DataDir(), workDir, job.Id)
	if err := os.MkdirAll(work, 0o750); err != nil {
		return err
	}
	defer func() { _ = os.RemoveAll(work) }()

	imp := &importer{r: r, ctx: ctx, a: a, owner: job.GetString("owner"), work: work,
		folders: map[int]string{}, albums: map[string]string{}, locks: map[string]*sync.Mutex{}, albumsTouched: map[string]bool{}}
	todo := make(chan int)
	results := make(chan result)
	var wg sync.WaitGroup
	for range max(1, r.Workers) {
		wg.Go(func() {
			for i := range todo {
				results <- imp.process(i, p.items[i])
			}
		})
	}
	var remaining []int // read before the collector starts changing prog
	for i := range p.items {
		if !prog.done(i) {
			remaining = append(remaining, i)
		}
	}
	go func() {
		defer close(todo)
		for _, i := range remaining {
			if !r.waitForMedia(ctx) {
				return
			}
			select {
			case todo <- i:
			case <-ctx.Done():
				return
			}
		}
	}()
	go func() { wg.Wait(); close(results) }()

	var failures []map[string]string
	_ = job.UnmarshalJSONField("failures", &failures)
	failBytes := 0
	if b, err := json.Marshal(failures); err == nil {
		failBytes = len(b)
	}
	var fatal error
	last := time.Now()
	for res := range results {
		if res.err != nil {
			if fatal == nil {
				fatal = res.err
				r.mu.Lock()
				if r.cancel != nil {
					r.cancel(res.err)
				}
				r.mu.Unlock()
			}
			continue
		}
		prog.mark(res.index)
		job.Set("processed", job.GetInt("processed")+1)
		switch res.outcome {
		case imported:
			job.Set("imported", job.GetInt("imported")+1)
			if res.undated {
				job.Set("undated", job.GetInt("undated")+1)
			}
		case duplicate:
			job.Set("duplicates", job.GetInt("duplicates")+1)
		case skipped:
			job.Set("skipped", job.GetInt("skipped")+1)
		case failed:
			job.Set("failed", job.GetInt("failed")+1)
			f := map[string]string{"path": truncateRunes(p.items[res.index].path, maxFailurePath), "reason": res.reason}
			if b, err := json.Marshal(f); err == nil && len(failures) < maxFailures && failBytes+len(b) < maxFailuresBytes {
				failures = append(failures, f)
				failBytes += len(b) + 1
			}
		}
		if time.Since(last) >= saveEvery {
			r.saveProgress(job, &prog, failures, imp)
			last = time.Now()
		}
	}
	r.saveProgress(job, &prog, failures, imp)
	if fatal != nil {
		return fatal
	}
	return ctx.Err()
}

func (r *Runner) saveProgress(job *core.Record, prog *progress, failures []map[string]string, imp *importer) {
	job.Set("progress", prog)
	job.Set("attempts", 0) // it moves: restarts so far were not caused by this job
	if failures == nil {
		failures = []map[string]string{}
	}
	job.Set("failures", failures)
	imp.mu.Lock()
	job.Set("albums", max(job.GetInt("albums"), len(imp.albumsTouched)))
	imp.mu.Unlock()
	if err := r.app.Save(job); err != nil {
		r.app.Logger().Error("cannot save import progress", "import", job.Id, "error", err)
	}
}

// checkDisk: the remaining photos must fit on the disk (with local storage), keeping its floor free and
// counting what partial uploads still announce. Each content counts once (album copies), trashed items
// not at all.
func (r *Runner) checkDisk(items []item, prog *progress) error {
	var need, largest int64
	seen := map[string]bool{}
	for i, it := range items {
		if prog.done(i) || it.meta.Trashed || seen[it.contentKey()] {
			continue
		}
		seen[it.contentKey()] = true
		need = satAdd(need, it.size)
		largest = max(largest, it.size)
	}
	if r.app.Settings().S3.Enabled {
		need = satMul(largest, int64(max(1, r.Workers))) // only the temp copies stay local
	}
	if !FitsOnDisk(r.app.DataDir(), need, true, ImportFloor) {
		return errDisk
	}
	return nil
}

// waitForMedia pauses while the media worker is far behind. False when the job is stopped.
func (r *Runner) waitForMedia(ctx context.Context) bool {
	for {
		n, err := r.app.CountRecords(media.Collection, dbx.HashExp{"status": "pending"})
		if err != nil || n < maxPendingMedia {
			return ctx.Err() == nil
		}
		select {
		case <-ctx.Done():
			return false
		case <-time.After(2 * time.Second):
		}
	}
}

// importer imports the items of one job.
type importer struct {
	r     *Runner
	ctx   context.Context
	a     *archives
	owner string
	work  string

	mu            sync.Mutex
	folders       map[int]string    // year (0 = root) → folder id
	albums        map[string]string // title → album id
	albumsTouched map[string]bool
	locks         map[string]*sync.Mutex // by SHA-256: two copies of a photo never both get imported
}

func (imp *importer) process(i int, it item) result {
	res := result{index: i}
	if err := imp.ctx.Err(); err != nil {
		res.err = err
		return res
	}
	if it.meta.Trashed {
		res.outcome = skipped
		return res
	}
	fail := func(reason string) result { res.outcome, res.reason = failed, reason; return res }
	app := imp.r.app

	// The quota is checked before anything is decompressed (a duplicate is recognized only after).
	if err := drive.CheckQuota(app, imp.owner, it.size, ""); err != nil {
		res.err = err
		if drive.IsQuotaError(err) {
			res.err = errQuota
		}
		return res
	}
	tmp, sum, err := imp.extract(it)
	if tmp != "" {
		defer func() { _ = os.Remove(tmp) }()
	}
	switch {
	case imp.ctx.Err() != nil:
		res.err = imp.ctx.Err()
		return res
	case errors.Is(err, errBudget):
		res.err = errUnsafeJob
		return res
	case errors.Is(err, errTooLarge):
		return fail("too_large")
	case errors.Is(err, errSuspicious):
		return fail("suspicious_compression")
	case err != nil:
		return fail("unreadable")
	}
	// Only photos and videos become files (a ".jpg" holding anything else is refused); camera RAW
	// formats the sniffer does not know are let through.
	mt, err := mimetype.DetectFile(tmp)
	unknownRAW := rawExts[strings.ToLower(path.Ext(it.name()))] && mt != nil && mt.Is("application/octet-stream")
	if err != nil || (media.KindOf(mt.String()) == "" && !unknownRAW) {
		return fail("unsupported")
	}

	unlock := imp.lock(sum)
	defer unlock()
	existing, err := findBySHA(app, imp.owner, sum, "")
	if err != nil {
		res.err = err
		return res
	}
	if existing != nil {
		imp.completeDuplicate(existing, it)
		res.outcome = duplicate
		return res
	}

	parent, err := imp.folder(yearOf(it))
	if err != nil {
		res.err = err
		return res
	}
	albumID := ""
	if it.album != "" {
		if albumID, err = imp.album(it.album); err != nil {
			app.Logger().Warn("cannot create an imported album", "error", err)
		}
	}
	// Saving copies the file into storage: outside any transaction, so the database stays writable.
	m := it.meta
	media.Annotate(imp.owner, sum, media.Imported{Taken: m.Taken, HasLocation: m.HasLocation, Lat: m.Lat, Lon: m.Lon,
		Description: m.Description, Favorite: m.Favorite})
	node, err := drive.SaveNewFileKnown(app, imp.owner, parent, nodeName(it.name()), func() (*filesystem.File, error) {
		return filesystem.NewFileFromPath(tmp)
	}, it.size, sum)
	media.Forget(imp.owner, sum)
	switch {
	case drive.IsQuotaError(err):
		res.err = errQuota
		return res
	case err != nil:
		app.Logger().Warn("cannot save an imported photo", "path", it.path, "error", err)
		return fail("save_failed")
	}
	// A phone backup may have saved the same photo meanwhile: the later copy goes.
	if earlier, err := findBySHA(app, imp.owner, sum, node.Id); err == nil && earlier != nil && isBefore(earlier, node) {
		if err := app.Delete(node); err == nil {
			imp.completeDuplicate(earlier, it)
			res.outcome = duplicate
			return res
		}
	}
	if albumID != "" {
		if rec, err := app.FindFirstRecordByData(media.Collection, "node", node.Id); err == nil {
			if err := addItem(app, albumID, rec.Id, imp.owner); err != nil {
				app.Logger().Warn("cannot add an imported photo to its album", "error", err)
			} else {
				imp.mu.Lock()
				imp.albumsTouched[albumID] = true
				imp.mu.Unlock()
			}
		}
	}
	res.outcome = imported
	res.undated = !it.hasMeta || it.meta.Taken.IsZero()
	return res
}

// rawExts are camera RAW formats, kept even when their type is not recognized.
var rawExts = map[string]bool{".dng": true, ".cr2": true, ".cr3": true, ".nef": true, ".arw": true, ".orf": true, ".rw2": true, ".raf": true}

// yearOf is the folder year: Takeout's own ("Photos from 2019"), else the date taken in the server's
// time zone, else 0 (the root folder).
func yearOf(it item) int {
	if it.year != 0 {
		return it.year
	}
	if !it.meta.Taken.IsZero() {
		return it.meta.Taken.In(time.Local).Year()
	}
	return 0
}

// findBySHA returns the owner's oldest file with this content (trash included), except one node.
func findBySHA(app core.App, owner, sum, except string) (*core.Record, error) {
	var found []*core.Record
	q := app.RecordQuery(drive.Collection).
		AndWhere(dbx.HashExp{"owner": owner, "kind": drive.KindFile, "sha256": sum})
	if except != "" {
		q = q.AndWhere(dbx.Not(dbx.HashExp{"id": except}))
	}
	if err := q.OrderBy("created", "id").Limit(1).All(&found); err != nil || len(found) == 0 {
		return nil, err
	}
	return found[0], nil
}

func isBefore(a, b *core.Record) bool {
	ta, tb := a.GetDateTime("created").Time(), b.GetDateTime("created").Time()
	return ta.Before(tb) || ta.Equal(tb) && a.Id < b.Id
}

// completeDuplicate adds an already present photo to its album, and gives it Google's favorite and
// description when it has none (never overwriting what the user set).
func (imp *importer) completeDuplicate(node *core.Record, it item) {
	if !node.GetDateTime("trashed_at").IsZero() {
		return
	}
	app := imp.r.app
	rec, err := app.FindFirstRecordByData(media.Collection, "node", node.Id)
	if err != nil {
		return
	}
	changed, reprocess := false, false
	// Google's date and place, when the record has none yet (also a photo imported just before a
	// crash, whose metadata only lived in memory): the worker merges them with the file's own.
	m := it.meta
	if !m.Taken.IsZero() && rec.GetDateTime("import_taken_at").IsZero() {
		rec.Set("import_taken_at", m.Taken)
		changed = true
		// Same day as the date shown: merging cannot change it, no need to process the file again.
		reprocess = rec.GetDateTime("taken_at").Time().Sub(m.Taken).Abs() > 24*time.Hour
	}
	if m.HasLocation && !rec.GetBool("import_has_location") {
		rec.Set("import_has_location", true)
		rec.Set("import_lat", m.Lat)
		rec.Set("import_lon", m.Lon)
		changed = true
		reprocess = reprocess || !rec.GetBool("has_location")
	}
	if reprocess {
		rec.Set("status", "pending")
	}
	if it.meta.Favorite && !rec.GetBool("favorite") {
		rec.Set("favorite", true)
		changed = true
	}
	if it.meta.Description != "" && rec.GetString("description") == "" {
		rec.Set("description", it.meta.Description)
		changed = true
	}
	if changed {
		if err := app.Save(rec); err != nil {
			app.Logger().Warn("cannot complete an already present photo", "error", err)
		} else if reprocess {
			media.Requeue(app, rec.Id)
		}
	}
	if it.album != "" {
		if err := imp.addToAlbum(app, it.album, rec.Id); err != nil {
			app.Logger().Warn("cannot add an imported photo to its album", "error", err)
		}
	}
}

// extract streams an entry into a temp file and hashes it.
func (imp *importer) extract(it item) (string, string, error) {
	f, err := os.CreateTemp(imp.work, "entry-*")
	if err != nil {
		return "", "", err
	}
	h := sha256.New()
	_, err = imp.a.copyEntry(imp.ctx, it.entry, io.MultiWriter(f, h))
	if cerr := f.Close(); err == nil {
		err = cerr
	}
	return f.Name(), hex.EncodeToString(h.Sum(nil)), err
}

func (imp *importer) lock(sum string) func() {
	imp.mu.Lock()
	l := imp.locks[sum]
	if l == nil {
		l = &sync.Mutex{}
		imp.locks[sum] = l
	}
	imp.mu.Unlock()
	l.Lock()
	return l.Unlock
}

// folder returns "Google Photos" (year 0) or "Google Photos/<year>", reusing or creating them.
func (imp *importer) folder(year int) (string, error) {
	imp.mu.Lock()
	defer imp.mu.Unlock()
	if id, ok := imp.folders[year]; ok {
		return id, nil
	}
	root, ok := imp.folders[0]
	if !ok {
		var err error
		if root, err = ensureFolder(imp.r.app, imp.owner, "", RootFolder); err != nil {
			return "", err
		}
		imp.folders[0] = root
	}
	if year == 0 {
		return root, nil
	}
	id, err := ensureFolder(imp.r.app, imp.owner, root, strconv.Itoa(year))
	if err != nil {
		return "", err
	}
	imp.folders[year] = id
	return id, nil
}

func ensureFolder(app core.App, owner, parent, name string) (string, error) {
	var found []*core.Record
	err := app.RecordQuery(drive.Collection).AndWhere(dbx.NewExp(
		"owner = {:owner} AND parent = {:parent} AND kind = 'folder' AND trashed_at = '' AND name = {:name} COLLATE NOCASE",
		dbx.Params{"owner": owner, "parent": parent, "name": name})).Limit(1).All(&found)
	if err != nil {
		return "", err
	}
	if len(found) > 0 {
		return found[0].Id, nil
	}
	col, err := app.FindCollectionByNameOrId(drive.Collection)
	if err != nil {
		return "", err
	}
	free, err := drive.AvailableName(app, owner, parent, name) // a file may use the name
	if err != nil {
		return "", err
	}
	f := core.NewRecord(col)
	f.Set("owner", owner)
	f.Set("parent", parent)
	f.Set("name", free)
	f.Set("kind", drive.KindFolder)
	if err := app.Save(f); err != nil {
		return "", err
	}
	return f.Id, nil
}

// album returns the user's album with this title, creating it (re-running an import reuses it).
func (imp *importer) album(title string) (string, error) {
	imp.mu.Lock()
	defer imp.mu.Unlock()
	if id, ok := imp.albums[title]; ok {
		return id, nil
	}
	rec, err := imp.r.app.FindFirstRecordByFilter(albums.Collection, "owner = {:o} && name = {:n}",
		dbx.Params{"o": imp.owner, "n": title})
	if err != nil && !errors.Is(err, sql.ErrNoRows) {
		return "", err
	}
	if err != nil {
		col, cerr := imp.r.app.FindCollectionByNameOrId(albums.Collection)
		if cerr != nil {
			return "", cerr
		}
		rec = core.NewRecord(col)
		rec.Set("owner", imp.owner)
		rec.Set("name", title)
		if err := imp.r.app.Save(rec); err != nil {
			return "", err
		}
	}
	imp.albums[title] = rec.Id
	return rec.Id, nil
}

func (imp *importer) addToAlbum(app core.App, title, mediaID string) error {
	id, err := imp.album(title)
	if err != nil {
		return err
	}
	if err := addItem(app, id, mediaID, imp.owner); err != nil {
		return err
	}
	imp.mu.Lock()
	imp.albumsTouched[id] = true
	imp.mu.Unlock()
	return nil
}

// addItem adds a photo to an album once.
func addItem(app core.App, album, mediaID, owner string) error {
	if _, err := app.FindFirstRecordByFilter(albums.Items, "album = {:a} && media = {:m}",
		dbx.Params{"a": album, "m": mediaID}); err == nil {
		return nil
	}
	col, err := app.FindCollectionByNameOrId(albums.Items)
	if err != nil {
		return err
	}
	rec := core.NewRecord(col)
	rec.Set("album", album)
	rec.Set("media", mediaID)
	rec.Set("added_by", owner)
	return app.Save(rec)
}

// nodeName makes an entry name acceptable for the drive.
func nodeName(name string) string {
	clean := strings.Map(func(r rune) rune {
		if r == '/' || unicode.IsControl(r) || unicode.Is(unicode.Cf, r) {
			return '_'
		}
		return r
	}, name)
	if r := []rune(clean); len(r) > drive.NameMaxLen {
		ext := path.Ext(clean)
		clean = string(r[:drive.NameMaxLen-len([]rune(ext))]) + ext
	}
	if !drive.ValidName(clean) {
		if ext := strings.ToLower(path.Ext(name)); len(ext) > 1 && drive.ValidName("p"+ext) {
			return "photo" + ext
		}
		return "photo"
	}
	return clean
}

// truncateRunes cuts s to n characters, marking the cut.
func truncateRunes(s string, n int) string {
	if r := []rune(s); len(r) > n {
		return string(r[:n-1]) + "…"
	}
	return s
}
