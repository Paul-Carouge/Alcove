// Package appdist serves the Android app matching the server's version, for in-app updates (ADR 0024).
// The APK is downloaded once from the GitHub release of that version and cached in the data directory.
// Phones that name their ABI get the smaller per-ABI APK when the release has one (ADR 0029).
package appdist

import (
	"context"
	"net/http"
	"os"
	"path/filepath"
	"slices"
	"strings"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

const (
	// Asset is the universal APK of a release (see .github/workflows/release.yml); app versions up to
	// 0.29.0 always download it.
	Asset    = "alcove-android.apk"
	maxSize  = 300 << 20
	cacheFor = time.Hour
)

// ABIs with their own release asset, alcove-android-<abi>.apk (Flutter's --split-per-abi).
var ABIs = []string{"arm64-v8a", "armeabi-v7a", "x86_64"}

// assetFor is the release file of an ABI ("" = the universal APK).
func assetFor(abi string) string {
	if abi == "" {
		return Asset
	}
	return "alcove-android-" + abi + ".apk"
}

// Dist answers "which app goes with this server" and serves it.
type Dist struct {
	version string
	client  *updater.Client
	dir     string

	mu      sync.Mutex // guards the release cache
	dlMu    sync.Mutex // one APK download at a time
	checked time.Time
	release *updater.Release
}

// Register mounts the routes. version is the server's own (buildinfo.Version).
func Register(app core.App, client *updater.Client, version string) *Dist {
	d := &Dist{version: strings.TrimPrefix(version, "v"), client: client}
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		d.dir = filepath.Join(se.App.DataDir(), "app")
		d.prune()
		se.Router.GET("/api/v1/app/android", d.info).Bind(apis.RequireAuth("users"))
		se.Router.GET("/api/v1/app/android.apk", d.download)
		return se.Next()
	})
	return d
}

// prune deletes the APKs (and partial downloads) of other versions.
func (d *Dist) prune() {
	entries, _ := os.ReadDir(d.dir)
	keep := map[string]bool{filepath.Base(d.cached("")): true}
	for _, abi := range ABIs {
		keep[filepath.Base(d.cached(abi))] = true
	}
	for _, e := range entries {
		if !keep[e.Name()] && strings.HasPrefix(e.Name(), "alcove-android-") {
			_ = os.Remove(filepath.Join(d.dir, e.Name()))
		}
	}
}

// releasable: development builds ("0.18.1-3-gabc", "0.0.0-dev") have no release to offer.
func (d *Dist) releasable() bool {
	return d.client != nil && d.version != "" && !strings.Contains(d.version, "-")
}

// lookup returns the release of the server's version (cached for an hour), or nil.
func (d *Dist) lookup(ctx context.Context) *updater.Release {
	if !d.releasable() {
		return nil
	}
	d.mu.Lock()
	defer d.mu.Unlock()
	if time.Since(d.checked) < cacheFor {
		return d.release
	}
	rel, err := d.client.Release(ctx, d.version)
	d.checked = time.Now()
	if err != nil || rel.Assets[Asset] == "" {
		d.release = nil
	} else {
		d.release = rel
	}
	return d.release
}

// cached is where the APK of an ABI ("" = universal) for the server's version is kept.
func (d *Dist) cached(abi string) string {
	name := "alcove-android-" + d.version
	if abi != "" {
		name += "-" + abi
	}
	return filepath.Join(d.dir, name+".apk")
}

func (d *Dist) info(e *core.RequestEvent) error {
	ctx, cancel := context.WithTimeout(e.Request.Context(), 15*time.Second)
	defer cancel()
	res := map[string]any{"version": d.version, "available": d.lookup(ctx) != nil}
	if st, err := os.Stat(d.cached("")); err == nil {
		res["size"] = st.Size()
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, res)
}

func (d *Dist) download(e *core.RequestEvent) error {
	user, err := e.App.FindAuthRecordByToken(e.Request.URL.Query().Get("token"), core.TokenTypeFile)
	if err != nil || user.Collection().Name != "users" {
		return e.UnauthorizedError("A valid file token is required.", nil)
	}
	abi := e.Request.URL.Query().Get("abi")
	if !slices.Contains(ABIs, abi) {
		abi = "" // absent (apps up to 0.29.0) or unknown: the universal APK
	}
	path := d.cached(abi)
	if _, err := os.Stat(path); err != nil {
		// Not tied to the phone's request: if it gives up, the download still fills the cache for its
		// retry.
		ctx, cancel := context.WithTimeout(context.WithoutCancel(e.Request.Context()), 10*time.Minute)
		defer cancel()
		rel := d.lookup(ctx)
		if rel == nil || rel.Assets[assetFor(abi)] == "" {
			// No per-ABI APK in the release, or GitHub unreachable: the universal APK, if any.
			abi, path = "", d.cached("")
		}
		if _, err := os.Stat(path); err == nil {
			return d.serve(e, path)
		}
		if rel == nil {
			return e.NotFoundError("No Android app for this server version.", nil)
		}
		d.dlMu.Lock()
		err := func() error {
			defer d.dlMu.Unlock()
			if _, err := os.Stat(path); err == nil {
				return nil // downloaded by a concurrent request
			}
			if err := os.MkdirAll(d.dir, 0o750); err != nil {
				return err
			}
			return d.client.SaveAsset(ctx, rel, assetFor(abi), path, maxSize)
		}()
		if err != nil {
			e.App.Logger().Warn("android app download failed", "version", d.version, "error", err)
			return e.Error(http.StatusBadGateway, "The app could not be downloaded from the release.", nil)
		}
	}
	return d.serve(e, path)
}

func (d *Dist) serve(e *core.RequestEvent, path string) error {
	f, err := os.Open(path) // #nosec G304 -- fixed name in the data directory
	if err != nil {
		return err
	}
	defer func() { _ = f.Close() }()
	st, err := f.Stat()
	if err != nil {
		return err
	}
	h := e.Response.Header()
	h.Set("Content-Type", "application/vnd.android.package-archive")
	h.Set("Content-Disposition", `attachment; filename="alcove-`+d.version+`.apk"`)
	h.Set("Cache-Control", "private, max-age=3600")
	http.ServeContent(e.Response, e.Request, "alcove.apk", st.ModTime(), f)
	return nil
}
