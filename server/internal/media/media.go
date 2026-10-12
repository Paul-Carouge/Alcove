// Package media keeps one "media" record per photo or video in the drive and
// fills it in the background: metadata (EXIF / ffprobe) and, for formats
// PocketBase cannot thumbnail (HEIC, videos…), JPEG thumbnails via ffmpeg.
// Originals are never modified.
package media

import (
	"context"
	"errors"
	"fmt"
	"image"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"sync"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

const (
	Collection = "media"
	// Module is advertised in /health.
	Module    = "photos"
	queueSize = 4096
)

// nativeThumbs are image types Go can thumbnail itself (no ffmpeg needed).
var nativeThumbs = map[string]bool{"image/jpeg": true, "image/png": true, "image/gif": true, "image/webp": true}

// KindOf returns "image", "video" or "" for a MIME type.
func KindOf(mime string) string {
	m, _, _ := strings.Cut(mime, ";")
	switch {
	case m == "image/svg+xml":
		return ""
	case strings.HasPrefix(m, "image/"):
		return "image"
	case strings.HasPrefix(m, "video/"):
		return "video"
	}
	return ""
}

type worker struct {
	app   core.App
	queue chan string   // media record ids
	done  chan struct{} // closed on shutdown
	wg    sync.WaitGroup
	scan  sync.WaitGroup // startup scans
	once  sync.Once
}

// Register binds hooks, the favorite route and the background workers.
func Register(app core.App) {
	w := &worker{app: app, queue: make(chan string, queueSize), done: make(chan struct{})}

	track := func(e *core.RecordEvent) error {
		if err := e.Next(); err != nil {
			return err
		}
		w.track(e.Record)
		return nil
	}
	app.OnRecordAfterCreateSuccess(drive.Collection).BindFunc(track)
	app.OnRecordAfterUpdateSuccess(drive.Collection).BindFunc(track)

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.PUT("/api/v1/media/{id}/favorite", setFavorite).Bind(apis.RequireAuth("users"))
		se.Router.GET("/api/v1/media/{id}/original", original)
		se.Router.GET("/api/v1/photos/facets", facets).Bind(apis.RequireAuth("users"))
		se.Router.GET("/api/v1/photos/locations", locations).Bind(apis.RequireAuth("users"))
		w.start()
		return se.Next()
	})
	app.OnTerminate().BindFunc(func(e *core.TerminateEvent) error {
		w.stop()
		return e.Next()
	})
	// Failed items are retried once a day (e.g. after ffmpeg was installed).
	app.Cron().MustAdd("alcoveMediaRetry", "23 3 * * *", func() { w.requeue("failed") })
}

// track creates or resets the media record of a node when its content changes.
func (w *worker) track(node *core.Record) {
	kind := KindOf(node.GetString("mime"))
	if node.GetString("kind") != drive.KindFile || kind == "" || node.GetString("blob") == "" {
		return
	}
	rec, err := w.app.FindFirstRecordByData(Collection, "node", node.Id)
	contentChanged := err != nil || rec.GetString("status") == "failed" ||
		node.Original().GetString("blob") != node.GetString("blob")
	if !contentChanged {
		return
	}
	if err != nil {
		col, cerr := w.app.FindCollectionByNameOrId(Collection)
		if cerr != nil {
			w.app.Logger().Error("media collection missing", "error", cerr)
			return
		}
		rec = core.NewRecord(col)
		rec.Set("node", node.Id)
		rec.Set("owner", node.GetString("owner"))
	}
	rec.Set("kind", kind)
	rec.Set("status", "pending")
	rec.Set("error", "")
	if rec.GetDateTime("taken_at").IsZero() {
		rec.Set("taken_at", node.GetDateTime("created"))
	}
	if err := w.app.Save(rec); err != nil {
		w.app.Logger().Error("cannot track media", "node", node.Id, "error", err)
		return
	}
	w.enqueue(rec.Id)
}

func (w *worker) stopping() bool {
	select {
	case <-w.done:
		return true
	default:
		return false
	}
}

func (w *worker) enqueue(id string) {
	if w.done == nil || w.stopping() {
		return
	}
	select {
	case w.queue <- id:
	default:
		// Full queue: the record stays "pending" and is picked up at next start.
	}
}

func (w *worker) start() {
	w.once.Do(func() {
		n := min(2, max(1, runtime.NumCPU()/2))
		for range n {
			w.wg.Add(1)
			go w.loop()
		}
		w.scan.Add(1)
		go func() {
			defer w.scan.Done()
			w.backfill()
			w.requeue("failed")  // a new version (or a newly installed ffmpeg) may handle them now
			w.requeue("pending") // work interrupted by a restart
		}()
	})
}

func (w *worker) stop() {
	if w.stopping() {
		return
	}
	close(w.done)
	w.scan.Wait()
	w.once.Do(func() {}) // never start after stopping
	close(w.queue)
	w.wg.Wait()
}

// backfill tracks files uploaded before the photos module existed (v0.10) and reprocesses items made
// before every item had its own thumbnail (v0.11).
func (w *worker) backfill() {
	var untracked []*core.Record
	err := w.app.RecordQuery(drive.Collection).
		AndWhere(dbx.HashExp{"kind": drive.KindFile}).
		AndWhere(dbx.NewExp("blob != '' AND (mime LIKE 'image/%' OR mime LIKE 'video/%')")).
		AndWhere(dbx.NewExp("NOT EXISTS (SELECT 1 FROM " + Collection + " m WHERE m.node = nodes.id)")).
		All(&untracked)
	if err == nil {
		for _, n := range untracked {
			if w.stopping() {
				return
			}
			w.track(n)
		}
	}

	recs, err := w.app.FindAllRecords(Collection, dbx.HashExp{"status": "ready", "thumb": ""})
	if err != nil {
		return
	}
	for _, r := range recs {
		if w.stopping() {
			return
		}
		r.Set("status", "pending")
		_ = w.app.Save(r)
	}
	w.hashMissing()
}

// hashMissing computes the perceptual hash of items processed before v0.13, from their stored thumbnail.
func (w *worker) hashMissing() {
	recs, err := w.app.FindRecordsByFilter(Collection, "status = 'ready' && thumb != '' && phash = ''", "", 0, 0)
	if err != nil || len(recs) == 0 {
		return
	}
	fsys, err := w.app.NewFilesystem()
	if err != nil {
		return
	}
	defer func() { _ = fsys.Close() }()
	for _, r := range recs {
		if w.stopping() {
			return
		}
		rd, err := fsys.GetReader(r.BaseFilesPath() + "/" + r.GetString("thumb"))
		if err != nil {
			continue
		}
		h, err := DHash(rd)
		_ = rd.Close()
		if err == nil {
			r.Set("phash", h)
			_ = w.app.Save(r)
		}
	}
}

func (w *worker) requeue(status string) {
	recs, err := w.app.FindAllRecords(Collection, dbx.HashExp{"status": status})
	if err != nil {
		return
	}
	for _, r := range recs {
		if w.stopping() {
			return
		}
		if status == "failed" {
			r.Set("status", "pending")
			_ = w.app.Save(r)
		}
		w.enqueue(r.Id)
	}
}

func (w *worker) loop() {
	defer w.wg.Done()
	for id := range w.queue {
		_ = w.process(id) // errors are logged and kept on the record
	}
}

// Backfill runs the startup scan synchronously (exported for tests).
func Backfill(app core.App) { (&worker{app: app}).backfill() }

// Process handles one record synchronously (exported for tests).
func Process(app core.App, id string) error { return (&worker{app: app}).process(id) }

func (w *worker) process(id string) error {
	rec, err := w.app.FindRecordById(Collection, id)
	if err != nil || rec.GetString("status") != "pending" {
		return nil
	}
	node, err := w.app.FindRecordById(drive.Collection, rec.GetString("node"))
	if err != nil {
		return nil // deleted meanwhile (cascade removes the media record)
	}
	// The temp dir must outlive Save: PocketBase reads new files when saving.
	tmp, err := os.MkdirTemp("", "alcove-media-")
	if err != nil {
		return err
	}
	defer func() { _ = os.RemoveAll(tmp) }()
	if err := w.fill(rec, node, tmp); err != nil {
		rec.Set("status", "failed")
		rec.Set("error", truncate(err.Error(), 500))
		w.app.Logger().Warn("media processing failed", "node", node.Id, "error", err)
	} else {
		rec.Set("status", "ready")
		rec.Set("error", "")
	}
	if err := w.app.Save(rec); err != nil {
		w.app.Logger().Error("cannot save media", "media", rec.Id, "error", err)
		return err
	}
	return nil
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

// fill copies the original to a temp file (ffmpeg and EXIF need seeking),
// extracts metadata and builds thumbnails when needed.
func (w *worker) fill(rec, node *core.Record, tmp string) error {
	src := filepath.Join(tmp, "original")
	if err := w.copyOriginal(node, src); err != nil {
		return err
	}

	ctx := context.Background()
	mime, _, _ := strings.Cut(node.GetString("mime"), ";")
	video := rec.GetString("kind") == "video"
	var info Info
	var err error
	if video {
		if !HaveFFmpeg() {
			return errors.New("ffmpeg is not installed")
		}
		if info, err = VideoInfo(ctx, src); err != nil {
			return err
		}
	} else if info, err = ImageInfo(src); err != nil {
		return err
	}

	if !info.Taken.IsZero() {
		rec.Set("taken_at", info.Taken.UTC())
	}
	rec.Set("width", info.Width)
	rec.Set("height", info.Height)
	rec.Set("duration", info.Duration)
	rec.Set("camera_make", truncate(info.Make, 100))
	rec.Set("camera_model", truncate(info.Model, 100))
	rec.Set("lens", truncate(info.Lens, 150))
	rec.Set("exposure", truncate(info.Exposure, 100))
	rec.Set("has_location", info.HasLocation)
	rec.Set("lat", info.Lat)
	rec.Set("lon", info.Lon)

	// Every item gets its own derivatives: album members may see them, never the drive file itself.
	thumb, preview := filepath.Join(tmp, "thumb.jpg"), filepath.Join(tmp, "preview.jpg")
	switch {
	case HaveFFmpeg() && (!strings.HasPrefix(mime, "image/hei") || HEICSupported()):
		err = Derivatives(ctx, src, thumb, preview, video, info.Duration)
	case !video && nativeThumbs[mime]:
		err = GoDerivatives(src, thumb, preview, info.Orientation)
	case strings.HasPrefix(mime, "image/hei") && HaveFFmpeg():
		err = errors.New("HEIC thumbnails need ffmpeg 7.1 or newer")
	default:
		err = errors.New("ffmpeg is not installed (needed for " + mime + " thumbnails)")
	}
	if err != nil {
		return err
	}
	if !video && rec.GetInt("width") == 0 {
		fillSizeFromPreview(ctx, rec, src, preview)
	}
	if h, err := dhashFile(thumb); err == nil {
		rec.Set("phash", h)
	}
	for field, path := range map[string]string{"thumb": thumb, "preview": preview} {
		f, err := filesystem.NewFileFromPath(path)
		if err != nil {
			return err
		}
		f.OriginalName = field + ".jpg"
		rec.Set(field, f)
	}
	return nil
}

func (w *worker) copyOriginal(node *core.Record, dst string) error {
	fsys, err := w.app.NewFilesystem()
	if err != nil {
		return err
	}
	defer func() { _ = fsys.Close() }()
	r, err := fsys.GetReader(node.BaseFilesPath() + "/" + node.GetString("blob"))
	if err != nil {
		return fmt.Errorf("open original: %w", err)
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

func setFavorite(e *core.RequestEvent) error {
	var body struct {
		Favorite *bool `json:"favorite"`
	}
	if err := e.BindBody(&body); err != nil || body.Favorite == nil {
		return e.BadRequestError("favorite (boolean) is required.", nil)
	}
	rec, err := e.App.FindRecordById(Collection, e.Request.PathValue("id"))
	if err != nil || rec.GetString("owner") != e.Auth.Id {
		return e.NotFoundError("", nil)
	}
	rec.Set("favorite", *body.Favorite)
	if err := e.App.Save(rec); err != nil {
		return err
	}
	return e.NoContent(http.StatusNoContent)
}

// original serves the file of a photo or video to anyone the media view rule allows: its owner and
// the people of albums it is in (ADR 0018). The drive itself stays owner-only.
func original(e *core.RequestEvent) error {
	user, err := e.App.FindAuthRecordByToken(e.Request.URL.Query().Get("token"), core.TokenTypeFile)
	if err != nil || user.Collection().Name != "users" {
		return e.UnauthorizedError("A valid file token is required.", nil)
	}
	rec, err := e.App.FindRecordById(Collection, e.Request.PathValue("id"))
	if err != nil {
		return e.NotFoundError("", nil)
	}
	ok, err := e.App.CanAccessRecord(rec, &core.RequestInfo{Auth: user, Method: http.MethodGet}, rec.Collection().ViewRule)
	if err != nil || !ok {
		return e.NotFoundError("", nil)
	}
	node, err := e.App.FindRecordById(drive.Collection, rec.GetString("node"))
	if err != nil || node.GetString("blob") == "" || !node.GetDateTime("trashed_at").IsZero() {
		return e.NotFoundError("", nil)
	}
	return drive.Serve(e, node, e.Request.URL.Query().Get("inline") == "1")
}

// fillSizeFromPreview sets the size of images whose metadata does not say it (HEIC without EXIF size):
// the tile grid gives the size, the generated preview tells whether the picture is shown rotated.
func fillSizeFromPreview(ctx context.Context, rec *core.Record, src, preview string) {
	f, err := os.Open(preview) // #nosec G304 -- inside the worker's temp dir
	if err != nil {
		return
	}
	cfg, _, err := image.DecodeConfig(f)
	_ = f.Close()
	if err != nil || cfg.Height == 0 {
		return
	}
	w, h := cfg.Width, cfg.Height
	if _, gw, gh := HEIFGrid(ctx, src); gw > 0 && gh > 0 {
		w, h = gw, gh
		if (gw > gh) != (cfg.Width > cfg.Height) {
			w, h = gh, gw
		}
	}
	rec.Set("width", w)
	rec.Set("height", h)
}
