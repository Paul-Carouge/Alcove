package cli

import (
	"context"
	"fmt"
	"os/exec"
	"runtime"
	"time"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/ocr"
	"github.com/Paul-Carouge/Alcove/server/internal/service"
	"github.com/Paul-Carouge/Alcove/server/internal/toolbundle"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

// ocrComplete reports whether the system already has everything documents need.
func ocrComplete(t ocr.Tools) bool { return t.CanOCR() && t.CanReadPDF() && t.PDFRender }

// syncOCR installs or refreshes Alcove's own OCR tools (Linux, ADR 0025) from rel. When they are not
// installed yet it asks first (if ask) and does nothing if the system already has the tools.
func syncOCR(ctx context.Context, u *ui, spec service.Spec, c *updater.Client, rel *updater.Release, ask bool) (changed bool, err error) {
	dir := ocr.Bundle.Dir(spec.Binary)
	if toolbundle.Installed(dir) == "" {
		if !ask {
			return false, nil
		}
		if ocrComplete(ocr.Detect()) {
			u.say("  ✓ OCR tools found (Tesseract, poppler)")
			return false, nil
		}
		if !u.confirm(fmt.Sprintf("Read the text of scanned documents and screenshots so you can search them (OCR, French and English)? Installs %s's own tools: about 25 MB in %s; the system is not changed.", buildinfo.Name, dir), true) {
			return false, nil
		}
	}
	u.say("Downloading and verifying the OCR tools…")
	changed, err = ocr.Bundle.Install(ctx, c, rel, dir)
	if err != nil {
		return false, err
	}
	if runtime.GOOS == "linux" && spec.User != "" {
		_, _ = service.Runner("chown", "-R", spec.User+":"+spec.User, dir)
	}
	if changed {
		u.say("  ✓ OCR tools installed in %s", dir)
	} else {
		u.say("  ✓ OCR tools are up to date")
	}
	return changed, nil
}

// ensureOCR offers the OCR tools during installation: Alcove's own on Linux, the package manager
// elsewhere. Documents with a text layer and text files are searchable without them.
func ensureOCR(u *ui, spec service.Spec) {
	if toolbundle.Supported() {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Minute)
		defer cancel()
		c, rel, err := releaseForThisVersion(ctx)
		if err == nil {
			_, err = syncOCR(ctx, u, spec, c, rel, true)
		}
		if err != nil {
			u.say("  ! could not install the OCR tools (%v); an administrator can install them later from the System page", err)
		}
		return
	}
	if ocrComplete(ocr.Detect()) {
		u.say("  ✓ OCR tools found (Tesseract, poppler)")
		return
	}
	cmd := ocrInstallCommand()
	if cmd == nil {
		u.say("  ! OCR tools not found: install Tesseract and poppler to search scanned documents (optional)")
		return
	}
	if !u.confirm("Read the text of scanned documents and screenshots (OCR)? Installs Tesseract with its language models and poppler with "+cmd[0]+" (several hundred MB).", false) {
		return
	}
	if out, err := service.Runner(cmd[0], cmd[1:]...); err != nil {
		u.say("  ! OCR installation failed (%v); you can install it later.\n%s", err, lastLines(out, 5))
		return
	}
	u.say("  ✓ OCR tools installed")
}

func ocrInstallCommand() []string {
	switch {
	case runtime.GOOS == "darwin" && !isRoot():
		if _, err := exec.LookPath("brew"); err == nil {
			return []string{"brew", "install", "tesseract", "tesseract-lang", "poppler"}
		}
	case runtime.GOOS == "windows":
		if _, err := exec.LookPath("winget"); err == nil {
			return []string{"winget", "install", "--silent", "--accept-package-agreements", "--accept-source-agreements", "UB-Mannheim.TesseractOCR", "oschwartz10612.Poppler"}
		}
	}
	return nil
}

// ocrStatus is the line shown by "alcove status".
func ocrStatus(spec service.Spec) string {
	if dir := ocr.Bundle.Dir(spec.Binary); toolbundle.Installed(dir) != "" {
		return fmt.Sprintf("%s's own tools (%s)", buildinfo.Name, dir)
	}
	t := ocr.Detect()
	switch {
	case ocrComplete(t):
		return "Tesseract " + t.Tesseract
	case t.CanReadPDF():
		return "PDF text only; install the OCR tools from the System page to read scans"
	}
	return "not installed (optional)"
}
