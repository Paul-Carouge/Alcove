package docs

import (
	"context"
	"errors"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/ocr"
)

// Searchable PDFs: a copy of a scan whose text can be selected and searched in any PDF reader,
// made on request in the background and saved next to the original as "<name> (OCR).pdf".

const (
	jobQueue = 8
	// jobKeep is how long a finished job's result stays visible to GET.
	jobKeep = 30 * time.Minute
)

type job struct {
	Status   string `json:"status"` // running, done, failed
	Node     string `json:"node,omitempty"`
	Error    string `json:"error,omitempty"`
	finished time.Time
}

type jobs struct {
	mu    sync.Mutex
	byID  map[string]*job // source node id → job
	queue chan string
}

func newJobs() *jobs { return &jobs{byID: map[string]*job{}, queue: make(chan string, jobQueue)} }

func (j *jobs) get(id string) (job, bool) {
	j.mu.Lock()
	defer j.mu.Unlock()
	cur, ok := j.byID[id]
	if !ok {
		return job{}, false
	}
	return *cur, true
}

func (j *jobs) set(id string, update func(*job)) {
	j.mu.Lock()
	defer j.mu.Unlock()
	if cur, ok := j.byID[id]; ok {
		update(cur)
	}
}

// forget drops results older than jobKeep.
func (j *jobs) forget() {
	j.mu.Lock()
	defer j.mu.Unlock()
	for id, cur := range j.byID {
		if cur.Status != "running" && time.Since(cur.finished) > jobKeep {
			delete(j.byID, id)
		}
	}
}

// searchableSource checks that node can become a searchable PDF and returns its document record.
func (d *Docs) searchableSource(e *core.RequestEvent) (*core.Record, *core.Record, error) {
	node, err := e.App.FindRecordById(drive.Collection, e.Request.PathValue("id"))
	if err != nil || node.GetString("owner") != e.Auth.Id || node.GetString("kind") != drive.KindFile {
		return nil, nil, e.NotFoundError("", nil)
	}
	doc, err := e.App.FindFirstRecordByData(Collection, "node", node.Id)
	if err != nil || (doc.GetString("kind") != KindPDF && doc.GetString("kind") != KindImage) {
		return nil, nil, e.BadRequestError("Only PDFs and images can be made searchable.", nil)
	}
	return node, doc, nil
}

func (d *Docs) searchableGet(e *core.RequestEvent) error {
	if _, _, err := d.searchableSource(e); err != nil {
		return err
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	if cur, ok := d.jobs.get(e.Request.PathValue("id")); ok {
		return e.JSON(http.StatusOK, cur)
	}
	return e.JSON(http.StatusOK, job{Status: "idle"})
}

func (d *Docs) searchableStart(e *core.RequestEvent) error {
	node, _, err := d.searchableSource(e)
	if err != nil {
		return err
	}
	t := d.Tools()
	if !t.CanOCR() || !t.PDFRender {
		return e.Error(http.StatusConflict, "The OCR tools are not installed on this server.", nil)
	}
	d.jobs.forget()
	d.jobs.mu.Lock()
	if d.stopping() {
		d.jobs.mu.Unlock()
		return e.Error(http.StatusServiceUnavailable, "The server is stopping.", nil)
	}
	if cur, ok := d.jobs.byID[node.Id]; ok && cur.Status == "running" {
		d.jobs.mu.Unlock()
		return e.JSON(http.StatusAccepted, *cur)
	}
	select {
	case d.jobs.queue <- node.Id:
	default:
		d.jobs.mu.Unlock()
		return e.TooManyRequestsError("Too many searchable PDFs are being made; try again in a minute.", nil)
	}
	cur := &job{Status: "running"}
	d.jobs.byID[node.Id] = cur
	d.jobs.mu.Unlock()
	return e.JSON(http.StatusAccepted, *cur)
}

func (d *Docs) jobLoop() {
	defer d.wg.Done()
	for id := range d.jobs.queue {
		nodeID, err := d.makeSearchable(id)
		d.jobs.set(id, func(j *job) {
			j.finished = time.Now()
			if err != nil {
				j.Status = "failed"
				j.Error = truncate(err.Error(), 300)
			} else {
				j.Status = "done"
				j.Node = nodeID
			}
		})
		if err != nil && !d.stopping() {
			d.app.Logger().Warn("searchable PDF failed", "node", id, "error", err)
		}
	}
}

// makeSearchable builds the PDF and saves it as a new file; it returns the new node's id.
func (d *Docs) makeSearchable(id string) (string, error) {
	node, err := d.app.FindRecordById(drive.Collection, id)
	if err != nil {
		return "", errors.New("the file is gone")
	}
	doc, err := d.app.FindFirstRecordByData(Collection, "node", id)
	if err != nil {
		return "", errors.New("the file is not a document")
	}
	tmp, err := os.MkdirTemp("", "alcove-searchable-")
	if err != nil {
		return "", err
	}
	defer func() { _ = os.RemoveAll(tmp) }()
	ctx, cancel := context.WithTimeout(context.Background(), jobTimeout)
	defer cancel()
	go func() {
		select {
		case <-d.done:
			cancel()
		case <-ctx.Done():
		}
	}()

	tools := d.Tools()
	out := filepath.Join(tmp, "out.pdf")
	switch doc.GetString("kind") {
	case KindPDF:
		src := filepath.Join(tmp, "src.pdf")
		if err := d.copyTo(node, node.GetString("blob"), src); err != nil {
			return "", err
		}
		pages, err := ocr.PDFPages(ctx, src)
		if err != nil {
			return "", err
		}
		pages = min(pages, maxOCRPages)
		if pages > 1 && !tools.PDFUnite {
			return "", errors.New("pdfunite is not installed")
		}
		if err := ocr.SearchablePDF(ctx, src, tmp, out, pages, tools.Languages); err != nil {
			return "", err
		}
	default:
		src, err := d.imageForOCR(node, tmp)
		if err != nil {
			return "", err
		}
		if err := ocr.SearchablePDF(ctx, src, tmp, out, 0, tools.Languages); err != nil {
			return "", err
		}
	}

	base := strings.TrimSuffix(node.GetString("name"), filepath.Ext(node.GetString("name")))
	name, err := drive.AvailableName(d.app, node.GetString("owner"), node.GetString("parent"), base+" (OCR).pdf")
	if err != nil {
		return "", err
	}
	col, err := d.app.FindCollectionByNameOrId(drive.Collection)
	if err != nil {
		return "", err
	}
	f, err := filesystem.NewFileFromPath(out)
	if err != nil {
		return "", err
	}
	f.Name = "searchable.pdf"
	rec := core.NewRecord(col)
	rec.Set("owner", node.GetString("owner"))
	rec.Set("parent", node.GetString("parent"))
	rec.Set("name", name)
	rec.Set("kind", drive.KindFile)
	rec.Set("blob", f)
	if err := d.app.Save(rec); err != nil {
		if drive.IsQuotaError(err) {
			return "", errors.New("storage quota reached")
		}
		return "", err
	}
	return rec.Id, nil
}

// imageForOCR returns a local copy Tesseract can read: the original, or the preview for formats
// such as HEIC.
func (d *Docs) imageForOCR(node *core.Record, tmp string) (string, error) {
	mime := strings.ToLower(node.GetString("mime"))
	if ocrInputs[mime] && node.GetInt("size") <= maxImage {
		src := filepath.Join(tmp, "image"+extFor(mime))
		return src, d.copyTo(node, node.GetString("blob"), src)
	}
	m, err := d.app.FindFirstRecordByData(media.Collection, "node", node.Id)
	if err != nil || m.GetString("preview") == "" {
		return "", errors.New("no readable version of this image")
	}
	src := filepath.Join(tmp, "preview.jpg")
	return src, d.copyTo(m, m.GetString("preview"), src)
}

func extFor(mime string) string {
	switch mime {
	case "image/png":
		return ".png"
	case "image/tiff":
		return ".tif"
	case "image/webp":
		return ".webp"
	case "image/gif":
		return ".gif"
	case "image/bmp":
		return ".bmp"
	}
	return ".jpg"
}
