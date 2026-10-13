// Package docs reads the text of documents (ADR 0025): the text layer of PDFs, text files and, with
// OCR, scanned PDFs and images that look like documents (screenshots, scans: no camera metadata).
// One "documents" record per such file, filled in the background, and an FTS5 index searched by
// GET /api/v1/search. Originals are never modified.
package docs

import (
	"strings"
	"sync"
	"sync/atomic"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/ocr"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

const (
	Collection = "documents"
	// Module is advertised in /health while text can be read (at least PDFs or OCR).
	Module    = "documents"
	queueSize = 4096
	settings  = "app_settings"
	ocrKey    = "ocr.enabled"
)

// Kinds of documents.
const (
	KindPDF   = "pdf"
	KindText  = "text"
	KindImage = "image"
)

// Reasons a document is skipped; those in retryable are tried again when tools or settings change.
const (
	reasonOCROff       = "ocr-off"
	reasonNoTools      = "no-tools"
	reasonPhoto        = "photo"
	reasonUnsupported  = "unsupported"
	reasonTooLarge     = "too-large"
	reasonNotProcessed = "media-failed"
)

var retryable = []string{reasonOCROff, reasonNoTools, reasonNotProcessed}

// textTypes are read as plain text.
var textTypes = map[string]bool{
	"text/plain": true, "text/markdown": true, "text/x-markdown": true, "text/csv": true,
}

// KindOf returns the document kind of a MIME type, or "".
func KindOf(mime string) string {
	m, _, _ := strings.Cut(mime, ";")
	m = strings.TrimSpace(strings.ToLower(m))
	switch {
	case m == "application/pdf":
		return KindPDF
	case textTypes[m]:
		return KindText
	case media.KindOf(m) == "image":
		return KindImage
	}
	return ""
}

// Options configure the module.
type Options struct {
	// Releases and Version locate the OCR bundle of this server's release (native Linux installs).
	Releases *updater.Client
	Version  string
	// CanInstall reports whether the server may install the OCR bundle itself (native install run by
	// a service manager, on Linux).
	CanInstall func() bool
	// Binary is the running executable; the bundle lives next to it.
	Binary string
	// Docker: the tools come with the image and cannot be installed from the app.
	Docker bool
}

// Docs is the documents module.
type Docs struct {
	app   core.App
	opts  Options
	tools atomic.Pointer[ocr.Tools]
	ocrOn atomic.Bool

	queue  chan string
	done   chan struct{}
	wg     sync.WaitGroup
	scan   sync.WaitGroup
	once   sync.Once
	instMu sync.Mutex // one bundle installation at a time
}

// Register binds hooks, routes and the background worker.
func Register(app core.App, opts Options) *Docs {
	d := newDocs(app, opts)
	track := func(e *core.RecordEvent) error {
		if err := e.Next(); err != nil {
			return err
		}
		d.track(e.Record)
		return nil
	}
	app.OnRecordAfterCreateSuccess(drive.Collection).BindFunc(track)
	app.OnRecordAfterUpdateSuccess(drive.Collection).BindFunc(track)
	app.OnRecordAfterDeleteSuccess(Collection).BindFunc(func(e *core.RecordEvent) error {
		unindex(e.App, e.Record.Id)
		return e.Next()
	})
	// Images wait for their media record (camera metadata, preview) before being read.
	app.OnRecordAfterUpdateSuccess(media.Collection).BindFunc(func(e *core.RecordEvent) error {
		if err := e.Next(); err != nil {
			return err
		}
		if st := e.Record.GetString("status"); st == "ready" || st == "failed" {
			if doc, err := e.App.FindFirstRecordByData(Collection, "node", e.Record.GetString("node")); err == nil &&
				doc.GetString("status") == "pending" {
				d.enqueue(doc.Id)
			}
		}
		return nil
	})

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		d.ocrOn.Store(loadOCR(se.App))
		se.Router.GET("/api/v1/search", d.search).Bind(apis.RequireAuth("users"))
		se.Router.GET("/api/v1/admin/ocr", d.adminGet).Bind(apis.RequireAuth("users"))
		se.Router.PUT("/api/v1/admin/ocr", d.adminSet).Bind(apis.RequireAuth("users"))
		se.Router.POST("/api/v1/admin/ocr/install", d.adminInstall).Bind(apis.RequireAuth("users"))
		d.start()
		return se.Next()
	})
	app.OnTerminate().BindFunc(func(e *core.TerminateEvent) error {
		d.stop()
		return e.Next()
	})
	app.Cron().MustAdd("alcoveDocumentsRetry", "41 3 * * *", func() {
		d.refreshTools()
		d.requeueFailed()
		d.requeueRetryable()
		prune(d.app)
	})
	return d
}

func newDocs(app core.App, opts Options) *Docs {
	d := &Docs{app: app, opts: opts, queue: make(chan string, queueSize), done: make(chan struct{})}
	d.refreshTools()
	return d
}

// Tools returns what is installed (as last detected).
func (d *Docs) Tools() ocr.Tools { return *d.tools.Load() }

func (d *Docs) refreshTools() ocr.Tools {
	t := ocr.Detect()
	d.tools.Store(&t)
	return t
}

// Modules returns the module name for /health when documents can be read.
func (d *Docs) Modules() []string {
	if t := d.Tools(); t.CanReadPDF() || t.CanOCR() {
		return []string{Module}
	}
	return nil
}

// loadOCR reads the setting; OCR is on unless an administrator turned it off.
func loadOCR(app core.App) bool {
	rec, err := app.FindFirstRecordByFilter(settings, "key = {:k}", dbx.Params{"k": ocrKey})
	if err != nil {
		return true
	}
	on := true
	_ = rec.UnmarshalJSONField("value", &on)
	return on
}

// track creates or resets the document record of a node when its content changes, and keeps the
// indexed name current.
func (d *Docs) track(node *core.Record) {
	kind := KindOf(node.GetString("mime"))
	if node.GetString("kind") != drive.KindFile || kind == "" || node.GetString("blob") == "" {
		return
	}
	rec, err := d.app.FindFirstRecordByData(Collection, "node", node.Id)
	if err == nil && node.Original().GetString("blob") == node.GetString("blob") {
		if node.Original().GetString("name") != node.GetString("name") && rec.GetString("status") == "ready" {
			index(d.app, rec, node.GetString("name"))
		}
		return
	}
	if err != nil {
		col, cerr := d.app.FindCollectionByNameOrId(Collection)
		if cerr != nil {
			d.app.Logger().Error("documents collection missing", "error", cerr)
			return
		}
		rec = core.NewRecord(col)
		rec.Set("node", node.Id)
		rec.Set("owner", node.GetString("owner"))
	}
	rec.Set("kind", kind)
	rec.Set("status", "pending")
	rec.Set("reason", "")
	rec.Set("error", "")
	if err := d.app.Save(rec); err != nil {
		d.app.Logger().Error("cannot track document", "node", node.Id, "error", err)
		return
	}
	d.enqueue(rec.Id)
}

func (d *Docs) stopping() bool {
	select {
	case <-d.done:
		return true
	default:
		return false
	}
}

func (d *Docs) enqueue(id string) {
	if d.stopping() {
		return
	}
	select {
	case d.queue <- id:
	default:
		// Full queue: the record stays "pending" and is picked up at next start.
	}
}

func (d *Docs) start() {
	d.once.Do(func() {
		// One worker: OCR is CPU-heavy and photos are processed at the same time.
		d.wg.Add(1)
		go d.loop()
		d.scan.Add(1)
		go func() {
			defer d.scan.Done()
			d.backfill()
			d.requeueFailed()
			d.requeueRetryable()
			d.requeue("pending")
		}()
	})
}

func (d *Docs) stop() {
	if d.stopping() {
		return
	}
	close(d.done)
	d.scan.Wait()
	d.once.Do(func() {})
	close(d.queue)
	d.wg.Wait()
}

func (d *Docs) loop() {
	defer d.wg.Done()
	for id := range d.queue {
		_ = d.process(id) // errors are logged and kept on the record
	}
}

// backfill tracks files uploaded before the documents module existed.
func (d *Docs) backfill() {
	var nodes []*core.Record
	err := d.app.RecordQuery(drive.Collection).
		AndWhere(dbx.HashExp{"kind": drive.KindFile}).
		AndWhere(dbx.NewExp("blob != '' AND (mime LIKE 'application/pdf%' OR mime LIKE 'text/%' OR mime LIKE 'image/%')")).
		AndWhere(dbx.NewExp("NOT EXISTS (SELECT 1 FROM " + Collection + " d WHERE d.node = nodes.id)")).
		All(&nodes)
	if err != nil {
		return
	}
	for _, n := range nodes {
		if d.stopping() {
			return
		}
		d.track(n)
	}
}

func (d *Docs) requeue(status string) {
	recs, err := d.app.FindAllRecords(Collection, dbx.HashExp{"status": status})
	if err != nil {
		return
	}
	for _, r := range recs {
		if d.stopping() {
			return
		}
		d.enqueue(r.Id)
	}
}

func (d *Docs) requeueFailed() { d.reset(dbx.HashExp{"status": "failed"}) }

// requeueRetryable resets documents skipped for a reason that may no longer hold.
func (d *Docs) requeueRetryable() {
	reasons := make([]any, len(retryable))
	for i, r := range retryable {
		reasons[i] = r
	}
	d.reset(dbx.And(dbx.HashExp{"status": "skipped"}, dbx.In("reason", reasons...)))
}

func (d *Docs) reset(where dbx.Expression) {
	recs, err := d.app.FindAllRecords(Collection, where)
	if err != nil {
		return
	}
	for _, r := range recs {
		if d.stopping() {
			return
		}
		r.Set("status", "pending")
		r.Set("reason", "")
		if err := d.app.Save(r); err == nil {
			d.enqueue(r.Id)
		}
	}
}

// Backfill tracks existing files synchronously (exported for tests).
func Backfill(app core.App) { newDocs(app, Options{}).backfill() }

// Process handles one record synchronously (exported for tests). ocrOn mirrors the setting.
func Process(app core.App, id string, ocrOn bool) error {
	d := newDocs(app, Options{})
	d.ocrOn.Store(ocrOn)
	return d.process(id)
}
