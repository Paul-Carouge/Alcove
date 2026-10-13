package docs

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/ocr"
)

const (
	// maxText is what is kept and indexed per document (the collection field allows 1 MB).
	maxText = 1 << 20
	// maxTextFile is how much of a text file is read.
	maxTextFile = 4 << 20
	// maxPDF bounds the PDFs read; bigger ones are skipped.
	maxPDF = 500 << 20
	// maxOCRPages is how many pages of a scanned PDF are recognised.
	maxOCRPages = 100
	// maxImage bounds originals given to Tesseract; bigger images use their preview.
	maxImage = 40 << 20
	// scanThreshold: a PDF whose text layer has fewer letters per page is treated as a scan.
	scanThreshold = 40
	// jobTimeout bounds one document.
	jobTimeout = 30 * time.Minute
)

// ocrInputs are image types Tesseract (Leptonica) reads directly.
var ocrInputs = map[string]bool{
	"image/png": true, "image/jpeg": true, "image/tiff": true, "image/webp": true,
	"image/gif": true, "image/bmp": true,
}

// outcome of reading one document.
type outcome struct {
	status string // ready, skipped, pending (wait for the media record)
	reason string
	method string
	text   string
	pages  int
}

func ready(method, text string, pages int) outcome {
	return outcome{status: "ready", method: method, text: text, pages: pages}
}

func skipped(reason string) outcome { return outcome{status: "skipped", reason: reason} }

func (d *Docs) process(id string) error {
	rec, err := d.app.FindRecordById(Collection, id)
	if err != nil || rec.GetString("status") != "pending" {
		return nil
	}
	node, err := d.app.FindRecordById(drive.Collection, rec.GetString("node"))
	if err != nil {
		return nil // deleted meanwhile (cascade removes the document)
	}
	tmp, err := os.MkdirTemp("", "alcove-docs-")
	if err != nil {
		return err
	}
	defer func() { _ = os.RemoveAll(tmp) }()
	ctx, cancel := context.WithTimeout(context.Background(), jobTimeout)
	defer cancel()
	go func() {
		select {
		case <-d.done:
			cancel() // shutting down: stop the running tool
		case <-ctx.Done():
		}
	}()

	out, err := d.read(ctx, rec, node, tmp)
	if out.status == "pending" && err == nil {
		return nil // the media hook enqueues it again
	}
	if err != nil {
		if d.stopping() {
			return nil // interrupted: stays pending, resumed at next start
		}
		rec.Set("status", "failed")
		rec.Set("error", truncate(err.Error(), 500))
		d.app.Logger().Warn("document text extraction failed", "node", node.Id, "error", err)
	} else {
		rec.Set("status", out.status)
		rec.Set("reason", out.reason)
		rec.Set("method", out.method)
		rec.Set("text", truncate(out.text, maxText))
		rec.Set("pages", out.pages)
		rec.Set("error", "")
	}
	if err := d.app.Save(rec); err != nil {
		d.app.Logger().Error("cannot save document", "document", rec.Id, "error", err)
		return err
	}
	if rec.GetString("status") == "ready" {
		index(d.app, rec, node.GetString("name"))
	} else {
		unindex(d.app, rec.Id)
	}
	return nil
}

func (d *Docs) read(ctx context.Context, rec, node *core.Record, tmp string) (outcome, error) {
	switch rec.GetString("kind") {
	case KindText:
		return d.readText(node)
	case KindPDF:
		return d.readPDF(ctx, node, tmp)
	case KindImage:
		return d.readImage(ctx, node, tmp)
	}
	return skipped(reasonUnsupported), nil
}

func (d *Docs) readText(node *core.Record) (outcome, error) {
	r, err := d.open(node, node.GetString("blob"))
	if err != nil {
		return outcome{}, err
	}
	defer func() { _ = r.Close() }()
	b, err := io.ReadAll(io.LimitReader(r, maxTextFile))
	if err != nil {
		return outcome{}, err
	}
	if !utf8.Valid(b) && !looksLikeText(b) {
		return skipped(reasonUnsupported), nil
	}
	return ready("text", ocr.Clean(string(b)), 0), nil
}

// looksLikeText accepts Latin-1 and similar files (no NUL bytes), which Clean makes valid UTF-8.
func looksLikeText(b []byte) bool {
	for _, c := range b[:min(len(b), 8192)] {
		if c == 0 {
			return false
		}
	}
	return true
}

func (d *Docs) readPDF(ctx context.Context, node *core.Record, tmp string) (outcome, error) {
	tools := d.Tools()
	if !tools.CanReadPDF() {
		return skipped(reasonNoTools), nil
	}
	if node.GetInt("size") > maxPDF {
		return skipped(reasonTooLarge), nil
	}
	src := filepath.Join(tmp, "doc.pdf")
	if err := d.copyTo(node, node.GetString("blob"), src); err != nil {
		return outcome{}, err
	}
	pages, err := ocr.PDFPages(ctx, src)
	if err != nil {
		return outcome{}, err
	}
	text, err := ocr.PDFText(ctx, src, pages)
	if err != nil {
		return outcome{}, err
	}
	if letters(text) >= scanThreshold*max(1, pages) {
		return ready("pdf", text, pages), nil
	}
	// Little or no text layer: a scan.
	if !d.ocrOn.Load() {
		if text != "" {
			return ready("pdf", text, pages), nil
		}
		return skipped(reasonOCROff), nil
	}
	if !tools.CanOCR() || !tools.PDFRender {
		if text != "" {
			return ready("pdf", text, pages), nil
		}
		return skipped(reasonNoTools), nil
	}
	scanned, err := ocr.OCRPDF(ctx, src, tmp, 1, min(pages, maxOCRPages), tools.Languages)
	if err != nil {
		return outcome{}, err
	}
	if letters(scanned) < letters(text) {
		return ready("pdf", text, pages), nil
	}
	return ready("ocr", scanned, pages), nil
}

func (d *Docs) readImage(ctx context.Context, node *core.Record, tmp string) (outcome, error) {
	if !d.ocrOn.Load() {
		return skipped(reasonOCROff), nil
	}
	tools := d.Tools()
	if !tools.CanOCR() {
		return skipped(reasonNoTools), nil
	}
	m, err := d.app.FindFirstRecordByData(media.Collection, "node", node.Id)
	if err != nil || m.GetString("status") == "pending" {
		return outcome{status: "pending"}, nil
	}
	// Camera photos are not documents (a photo of a page can still be added as a PDF scan).
	if m.GetString("camera_make") != "" || m.GetString("camera_model") != "" {
		return skipped(reasonPhoto), nil
	}
	mime := strings.ToLower(node.GetString("mime"))
	var src string
	switch {
	case ocrInputs[mime] && node.GetInt("size") <= maxImage:
		src = filepath.Join(tmp, "image")
		err = d.copyTo(node, node.GetString("blob"), src)
	case m.GetString("preview") != "":
		src = filepath.Join(tmp, "preview.jpg")
		err = d.copyTo(m, m.GetString("preview"), src)
	case m.GetString("status") == "failed":
		return skipped(reasonNotProcessed), nil
	default:
		return skipped(reasonUnsupported), nil
	}
	if err != nil {
		return outcome{}, err
	}
	text, err := ocr.OCRImage(ctx, src, tools.Languages)
	if err != nil {
		return outcome{}, err
	}
	// Tesseract finds stray characters in pictures without text: keep only real words.
	if letters(text) < 8 {
		text = ""
	}
	return ready("ocr", text, 1), nil
}

func letters(s string) int {
	n := 0
	for _, r := range s {
		if unicode.IsLetter(r) {
			n++
		}
	}
	return n
}

func (d *Docs) open(rec *core.Record, file string) (io.ReadCloser, error) {
	if file == "" {
		return nil, errors.New("no file")
	}
	fsys, err := d.app.NewFilesystem()
	if err != nil {
		return nil, err
	}
	r, err := fsys.GetReader(rec.BaseFilesPath() + "/" + file)
	if err != nil {
		_ = fsys.Close()
		return nil, fmt.Errorf("open file: %w", err)
	}
	return &closeBoth{ReadCloser: r, fs: fsys}, nil
}

type closeBoth struct {
	io.ReadCloser
	fs interface{ Close() error }
}

func (c *closeBoth) Close() error {
	err := c.ReadCloser.Close()
	_ = c.fs.Close()
	return err
}

func (d *Docs) copyTo(rec *core.Record, file, dst string) error {
	r, err := d.open(rec, file)
	if err != nil {
		return err
	}
	defer func() { _ = r.Close() }()
	out, err := os.Create(dst) // #nosec G304 -- inside our temp dir
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, r); err != nil {
		_ = out.Close()
		return err
	}
	return out.Close()
}

// truncate cuts s to at most n bytes without splitting a character.
func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	for n > 0 && !utf8.RuneStart(s[n]) {
		n--
	}
	return s[:n]
}
