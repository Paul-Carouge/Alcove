package docs

import (
	"context"
	"net/http"
	"runtime"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/ocr"
	"github.com/Paul-Carouge/Alcove/server/internal/toolbundle"
)

// installHint tells administrators how to get the tools where the app cannot install them.
func installHint() string {
	switch runtime.GOOS {
	case "darwin":
		return "brew install tesseract tesseract-lang poppler"
	case "windows":
		return "winget install UB-Mannheim.TesseractOCR oschwartz10612.Poppler"
	case "linux":
		return "sudo apt install tesseract-ocr tesseract-ocr-fra poppler-utils"
	}
	return ""
}

func (d *Docs) canInstall() bool {
	return !d.opts.Docker && toolbundle.Supported() && d.opts.CanInstall != nil && d.opts.CanInstall() &&
		d.opts.Releases != nil && d.opts.Binary != ""
}

func (d *Docs) status(app core.App) map[string]any {
	counts := map[string]int{"pending": 0, "ready": 0, "skipped": 0, "failed": 0}
	var rows []struct {
		Status string `db:"status"`
		N      int    `db:"n"`
	}
	_ = app.DB().Select("status", "COUNT(*) AS n").From(Collection).GroupBy("status").All(&rows)
	for _, r := range rows {
		counts[r.Status] = r.N
	}
	bundle := ""
	if d.opts.Binary != "" {
		if toolbundle.Installed(ocr.Bundle.Dir(d.opts.Binary)) != "" {
			bundle = ocr.Bundle.Dir(d.opts.Binary)
		}
	}
	return map[string]any{
		"enabled":    d.ocrOn.Load(),
		"tools":      d.Tools(),
		"bundle":     bundle,
		"canInstall": d.canInstall(),
		"hint":       installHint(),
		"counts":     counts,
	}
}

func admin(e *core.RequestEvent) bool { return e.Auth.GetString("role") == "admin" }

func (d *Docs) adminGet(e *core.RequestEvent) error {
	if !admin(e) {
		return e.ForbiddenError("Administrators only.", nil)
	}
	d.refreshTools() // the administrator may just have installed them
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, d.status(e.App))
}

func (d *Docs) adminSet(e *core.RequestEvent) error {
	if !admin(e) {
		return e.ForbiddenError("Administrators only.", nil)
	}
	var body struct {
		Enabled *bool `json:"enabled"`
	}
	if err := e.BindBody(&body); err != nil || body.Enabled == nil {
		return e.BadRequestError("enabled (boolean) is required.", nil)
	}
	rec, err := e.App.FindFirstRecordByFilter(settings, "key = {:k}", dbx.Params{"k": ocrKey})
	if err != nil {
		col, cerr := e.App.FindCollectionByNameOrId(settings)
		if cerr != nil {
			return cerr
		}
		rec = core.NewRecord(col)
		rec.Set("key", ocrKey)
	}
	rec.Set("value", *body.Enabled)
	if err := e.App.Save(rec); err != nil {
		return err
	}
	was := d.ocrOn.Swap(*body.Enabled)
	e.App.Logger().Info("OCR setting changed", "enabled", *body.Enabled, "by", e.Auth.Email())
	if *body.Enabled && !was {
		go d.requeueRetryable()
	}
	return e.JSON(http.StatusOK, d.status(e.App))
}

// adminInstall downloads the OCR bundle of this server's release, verifies it like an update and
// activates it without a restart.
func (d *Docs) adminInstall(e *core.RequestEvent) error {
	if !admin(e) {
		return e.ForbiddenError("Administrators only.", nil)
	}
	if !d.canInstall() {
		return e.BadRequestError("The OCR tools cannot be installed from the app on this server.", nil)
	}
	if !d.instMu.TryLock() {
		return e.Error(http.StatusConflict, "An installation is already running.", nil)
	}
	defer d.instMu.Unlock()
	ctx, cancel := context.WithTimeout(e.Request.Context(), 10*time.Minute)
	defer cancel()
	rel, err := d.opts.Releases.Release(ctx, d.opts.Version)
	if err != nil {
		return e.Error(http.StatusBadGateway, "Cannot find this version's release.", nil)
	}
	if _, err := ocr.Bundle.Install(ctx, d.opts.Releases, rel, ocr.Bundle.Dir(d.opts.Binary)); err != nil {
		e.App.Logger().Warn("OCR bundle installation failed", "error", err)
		return e.Error(http.StatusBadGateway, "The OCR tools could not be installed.", nil)
	}
	ocr.Bundle.Activate(d.opts.Binary)
	d.refreshTools()
	e.App.Logger().Info("OCR tools installed", "by", e.Auth.Email())
	go d.requeueRetryable()
	return e.JSON(http.StatusOK, d.status(e.App))
}
