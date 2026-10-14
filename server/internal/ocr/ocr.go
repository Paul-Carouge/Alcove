// Package ocr runs the external text tools (ADR 0025): poppler's pdftotext/pdftoppm/pdfinfo for
// PDFs and Tesseract for scanned pages and images. On native Linux installs they come from Alcove's
// own bundle (Bundle), elsewhere from the system (Docker image, Homebrew, winget).
package ocr

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/Paul-Carouge/Alcove/server/internal/toolbundle"
)

// Bundle is the OCR tool bundle of native Linux installs.
var Bundle = toolbundle.Bundle{Name: "ocr", Probe: "bin/tesseract"}

// Languages Tesseract reads, in order of preference, when their models are installed.
var Languages = []string{"fra", "eng"}

const (
	// pageTimeout bounds rendering or recognising one page; a whole PDF gets pageTimeout per page.
	pageTimeout = 2 * time.Minute
	// dpi for rendering scanned pages: a good trade-off between accuracy and speed for A4 scans.
	dpi = 200
	// maxOutput bounds what a tool may print (a 1000-page PDF of dense text is ~3 MB).
	maxOutput = 8 << 20
)

// ErrMissing means a required program is not installed.
var ErrMissing = errors.New("tool not installed")

// Tools describes what is installed.
type Tools struct {
	Tesseract string   `json:"tesseract"` // version, "" when missing
	Languages []string `json:"languages"` // installed among Languages
	PDFText   bool     `json:"pdfText"`   // pdftotext and pdfinfo
	PDFRender bool     `json:"pdfRender"` // pdftoppm
	PDFUnite  bool     `json:"pdfUnite"`  // pdfunite (searchable PDFs of several pages)
}

// CanReadPDF reports whether PDFs with a text layer can be read.
func (t Tools) CanReadPDF() bool { return t.PDFText }

// CanOCR reports whether images (and, with PDFRender, scanned PDFs) can be recognised.
func (t Tools) CanOCR() bool { return t.Tesseract != "" && len(t.Languages) > 0 }

var tessVersion = regexp.MustCompile(`tesseract v?(\d+\.\d+(?:\.\d+)?)`)

// Detect looks the tools up on PATH.
func Detect() Tools {
	var t Tools
	if _, err := exec.LookPath("tesseract"); err == nil {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		out, _ := run(ctx, "tesseract", "--version")
		if m := tessVersion.FindStringSubmatch(string(out)); m != nil {
			t.Tesseract = m[1]
		} else if len(out) > 0 {
			t.Tesseract = "unknown"
		}
		langs, _ := run(ctx, "tesseract", "--list-langs")
		have := map[string]bool{}
		for _, l := range strings.Fields(string(langs)) {
			have[l] = true
		}
		for _, l := range Languages {
			if have[l] {
				t.Languages = append(t.Languages, l)
			}
		}
	}
	_, e1 := exec.LookPath("pdftotext")
	_, e2 := exec.LookPath("pdfinfo")
	t.PDFText = e1 == nil && e2 == nil
	_, e3 := exec.LookPath("pdftoppm")
	t.PDFRender = e3 == nil
	_, e4 := exec.LookPath("pdfunite")
	t.PDFUnite = e4 == nil
	return t
}

// run executes a tool with a bounded output; stderr is returned in the error.
func run(ctx context.Context, name string, args ...string) ([]byte, error) {
	cmd := exec.CommandContext(ctx, name, args...) // #nosec G204 -- fixed programs, paths we created
	// Tesseract uses every core per page by default; one is enough and keeps the server responsive.
	cmd.Env = append(os.Environ(), "OMP_THREAD_LIMIT=1")
	var out, errb limitedBuffer
	out.max, errb.max = maxOutput, 4<<10
	cmd.Stdout, cmd.Stderr = &out, &errb
	if err := cmd.Run(); err != nil {
		if errors.Is(err, exec.ErrNotFound) {
			return nil, fmt.Errorf("%s: %w", name, ErrMissing)
		}
		if ctx.Err() != nil {
			return nil, fmt.Errorf("%s: timed out", name)
		}
		return nil, fmt.Errorf("%s: %w: %s", name, err, lastLine(errb.String()))
	}
	if out.overflow {
		return nil, fmt.Errorf("%s: output too large", name)
	}
	return out.Bytes(), nil
}

type limitedBuffer struct {
	bytes.Buffer
	max      int
	overflow bool
}

func (b *limitedBuffer) Write(p []byte) (int, error) {
	if room := b.max - b.Len(); len(p) > room {
		b.overflow = true
		if room > 0 {
			b.Buffer.Write(p[:room])
		}
		return len(p), nil
	}
	return b.Buffer.Write(p)
}

func lastLine(s string) string {
	s = strings.TrimSpace(s)
	if i := strings.LastIndexByte(s, '\n'); i >= 0 {
		s = s[i+1:]
	}
	return s
}

var pagesRe = regexp.MustCompile(`(?m)^Pages:\s+(\d+)`)

// PDFPages returns the number of pages of a PDF.
func PDFPages(ctx context.Context, path string) (int, error) {
	ctx, cancel := context.WithTimeout(ctx, pageTimeout)
	defer cancel()
	out, err := run(ctx, "pdfinfo", path)
	if err != nil {
		return 0, err
	}
	m := pagesRe.FindSubmatch(out)
	if m == nil {
		return 0, errors.New("pdfinfo: no page count")
	}
	return strconv.Atoi(string(m[1]))
}

// PDFText returns the text layer of a PDF (empty for scans), one form feed between pages.
func PDFText(ctx context.Context, path string, pages int) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, time.Duration(max(1, pages))*pageTimeout/4+pageTimeout)
	defer cancel()
	out, err := run(ctx, "pdftotext", "-q", "-enc", "UTF-8", path, "-")
	if err != nil {
		return "", err
	}
	return Clean(string(out)), nil
}

// OCRPDF renders pages first..last (1-based) and recognises them; tmp is a scratch directory.
func OCRPDF(ctx context.Context, path, tmp string, first, last int, langs []string) (string, error) {
	var b strings.Builder
	for p := first; p <= last; p++ {
		if err := ctx.Err(); err != nil {
			return "", err
		}
		prefix := filepath.Join(tmp, "page")
		pctx, cancel := context.WithTimeout(ctx, pageTimeout)
		_, err := run(pctx, "pdftoppm", "-q", "-r", strconv.Itoa(dpi), "-gray", "-png",
			"-f", strconv.Itoa(p), "-l", strconv.Itoa(p), "-singlefile", path, prefix)
		cancel()
		if err != nil {
			return "", err
		}
		text, err := OCRImage(ctx, prefix+".png", langs)
		_ = os.Remove(prefix + ".png")
		if err != nil {
			return "", err
		}
		if p > first {
			b.WriteString("\f")
		}
		b.WriteString(text)
	}
	return Clean(b.String()), nil
}

// OCRImage recognises the text of an image (PNG, JPEG, TIFF, WebP, GIF, BMP).
func OCRImage(ctx context.Context, path string, langs []string) (string, error) {
	if len(langs) == 0 {
		return "", fmt.Errorf("tesseract: no language model: %w", ErrMissing)
	}
	ctx, cancel := context.WithTimeout(ctx, pageTimeout)
	defer cancel()
	out, err := run(ctx, "tesseract", path, "stdout", "-l", strings.Join(langs, "+"))
	if err != nil {
		return "", err
	}
	return Clean(string(out)), nil
}

// SearchablePDF writes to out a PDF of the scan src whose text can be selected and searched: each
// page is rendered (PDF) or taken as is (image), recognised, and laid out by Tesseract as the picture
// with invisible text over it. pages is the number of pages of a PDF, 0 for an image.
func SearchablePDF(ctx context.Context, src, tmp, out string, pages int, langs []string) error {
	if len(langs) == 0 {
		return fmt.Errorf("tesseract: no language model: %w", ErrMissing)
	}
	lang := strings.Join(langs, "+")
	page := func(img, base string) error {
		pctx, cancel := context.WithTimeout(ctx, pageTimeout)
		defer cancel()
		_, err := run(pctx, "tesseract", img, base, "-l", lang, "pdf")
		return err
	}
	if pages == 0 {
		return page(src, strings.TrimSuffix(out, ".pdf"))
	}
	parts := make([]string, 0, pages)
	for p := 1; p <= pages; p++ {
		if err := ctx.Err(); err != nil {
			return err
		}
		base := filepath.Join(tmp, fmt.Sprintf("p%04d", p))
		pctx, cancel := context.WithTimeout(ctx, pageTimeout)
		// JPEG keeps the result small (a PNG page at 200 dpi is several megabytes).
		_, err := run(pctx, "pdftoppm", "-q", "-r", strconv.Itoa(dpi), "-jpeg", "-jpegopt", "quality=80",
			"-f", strconv.Itoa(p), "-l", strconv.Itoa(p), "-singlefile", src, base)
		cancel()
		if err != nil {
			return err
		}
		if err := page(base+".jpg", base); err != nil {
			return err
		}
		_ = os.Remove(base + ".jpg")
		parts = append(parts, base+".pdf")
	}
	if len(parts) == 1 {
		return os.Rename(parts[0], out)
	}
	uctx, cancel := context.WithTimeout(ctx, pageTimeout)
	defer cancel()
	_, err := run(uctx, "pdfunite", append(parts, out)...)
	return err
}

var (
	blankLines = regexp.MustCompile(`\n[ \t]*\n(?:[ \t]*\n)+`)
	spaces     = regexp.MustCompile(`[ \t]{2,}`)
)

// Clean makes extracted text valid UTF-8, without control characters (except newlines and form
// feeds between pages), runs of spaces or more than one blank line.
func Clean(s string) string {
	if !utf8.ValidString(s) {
		s = strings.ToValidUTF8(s, "")
	}
	s = strings.Map(func(r rune) rune {
		switch {
		case r == '\n' || r == '\f' || r == '\t':
			return r
		case r == '\r':
			return -1
		case r < 0x20 || r == 0x7f || r == 0xfffd:
			return -1
		}
		return r
	}, s)
	s = spaces.ReplaceAllString(s, " ")
	s = blankLines.ReplaceAllString(s, "\n\n")
	return strings.TrimSpace(s)
}
