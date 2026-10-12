// Package updates checks for new releases and lets administrators install
// them from the web or mobile app (ADR 0015). The CLI equivalent is
// "alcove update" (internal/cli).
package updates

import (
	"context"
	"errors"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"sync"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/backup"
	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/service"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

// Options configures the checker.
type Options struct {
	Enabled bool
	APIBase string
	Mode    string // native | docker | ""
	// Exit restarts the process after an update (os.Exit by default; the
	// service manager starts the new binary).
	Exit func()
	// PublicKey and Binary override the release key and the executable to
	// replace (tests).
	PublicKey string
	Binary    string
}

type state struct {
	Latest    string    `json:"latest,omitempty"`
	Notes     string    `json:"notes,omitempty"`
	URL       string    `json:"url,omitempty"`
	CheckedAt time.Time `json:"checkedAt,omitzero"`
	Error     string    `json:"error,omitempty"`
}

type checker struct {
	opts   Options
	client *updater.Client
	mu     sync.Mutex
	st     state
	busy   bool
}

// FromConfig derives options from the server configuration.
func FromConfig(cfg config.Config) Options {
	api := cfg.UpdateURL
	if api == "" {
		api = buildinfo.ReleasesAPI
	}
	return Options{Enabled: cfg.UpdateCheck, APIBase: api, Mode: cfg.InstallMode, Exit: func() { os.Exit(0) }}
}

// Register mounts the admin routes and the daily check.
func Register(app core.App, opts Options) {
	key := opts.PublicKey
	if key == "" {
		key = buildinfo.ReleasePublicKey
	}
	client, err := updater.New(opts.APIBase, buildinfo.Repo, key)
	if err != nil {
		panic(err) // the compiled-in key is invalid: a build error
	}
	c := &checker{opts: opts, client: client}

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		g := se.Router.Group("/api/v1/admin").Bind(apis.RequireAuth("users")).BindFunc(requireAdmin)
		g.GET("/system", c.system)
		g.POST("/updates/check", c.check)
		g.POST("/updates/apply", c.apply)
		if opts.Enabled {
			go func() {
				time.Sleep(10 * time.Second) // let the server finish starting
				c.refresh(se.App)
			}()
		}
		return se.Next()
	})
	if opts.Enabled {
		app.Cron().MustAdd("alcoveUpdateCheck", "41 4 * * *", func() { c.refresh(app) })
	}
}

func requireAdmin(e *core.RequestEvent) error {
	if e.Auth == nil || e.Auth.GetString("role") != "admin" {
		return e.ForbiddenError("Administrators only.", nil)
	}
	return e.Next()
}

func (c *checker) refresh(app core.App) {
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	rel, err := c.client.Latest(ctx)
	c.mu.Lock()
	defer c.mu.Unlock()
	c.st.CheckedAt = time.Now().UTC()
	if err != nil {
		c.st.Error = err.Error()
		app.Logger().Warn("update check failed", "error", err)
		return
	}
	c.st = state{Latest: rel.Version, Notes: rel.Notes, URL: rel.URL, CheckedAt: c.st.CheckedAt}
	if updater.Newer(buildinfo.Version, rel.Version) {
		app.Logger().Info("a new version is available", "current", buildinfo.Version, "latest", rel.Version)
	}
}

// canSelfUpdate: installed by "alcove install" and run by a service manager
// that restarts the process after it exits.
func (c *checker) canSelfUpdate() bool {
	return c.opts.Mode == "native" && os.Getenv(service.EnvInstalled) != ""
}

func (c *checker) info() map[string]any {
	c.mu.Lock()
	st := c.st
	c.mu.Unlock()
	mode := c.opts.Mode
	if mode == "" {
		mode = "manual"
	}
	_, ffErr := exec.LookPath("ffmpeg")
	out := map[string]any{
		"version":       buildinfo.Version,
		"installMode":   mode,
		"canSelfUpdate": c.canSelfUpdate(),
		"ffmpeg":        ffErr == nil,
		"update": map[string]any{
			"enabled":   c.opts.Enabled,
			"available": st.Latest != "" && updater.Newer(buildinfo.Version, st.Latest),
			"latest":    st.Latest, "notes": st.Notes, "url": st.URL,
			"checkedAt": st.CheckedAt, "error": st.Error,
		},
	}
	switch mode {
	case "docker":
		out["updateCommand"] = "./update.sh   (in the folder that contains docker-compose.yml)"
	case "manual":
		out["updateCommand"] = "sudo alcove update"
	}
	return out
}

func (c *checker) system(e *core.RequestEvent) error {
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, c.info())
}

func (c *checker) check(e *core.RequestEvent) error {
	c.refresh(e.App)
	return c.system(e)
}

var errBusy = errors.New("an update is already in progress")

func (c *checker) apply(e *core.RequestEvent) error {
	if !c.canSelfUpdate() {
		return e.BadRequestError("This installation cannot update itself: run the update command on the server.", nil)
	}
	c.mu.Lock()
	if c.busy {
		c.mu.Unlock()
		return e.BadRequestError(errBusy.Error(), nil)
	}
	c.busy = true
	c.mu.Unlock()
	release := func() { c.mu.Lock(); c.busy = false; c.mu.Unlock() }

	ctx, cancel := context.WithTimeout(e.Request.Context(), 10*time.Minute)
	defer cancel()
	rel, err := c.client.Latest(ctx)
	if err != nil {
		release()
		return e.Error(http.StatusBadGateway, "Cannot reach the release server.", nil)
	}
	if !updater.Newer(buildinfo.Version, rel.Version) {
		release()
		return e.BadRequestError("Already up to date.", nil)
	}
	self, err := c.opts.Binary, error(nil)
	if self == "" {
		if self, err = os.Executable(); err == nil {
			self, err = filepath.EvalSymlinks(self)
		}
	}
	if err != nil {
		release()
		return err
	}
	tmp, err := os.MkdirTemp(filepath.Dir(self), ".alcove-update-")
	if err != nil {
		release()
		return err
	}
	defer func() { _ = os.RemoveAll(tmp) }()

	newExe, err := c.client.Download(ctx, rel, tmp)
	if err != nil {
		release()
		e.App.Logger().Error("update download/verification failed", "error", err)
		return e.Error(http.StatusBadGateway, "The release could not be verified: "+err.Error(), nil)
	}
	if _, err := backup.Database(e.App, "pre-update-"+rel.Version); err != nil {
		release()
		return e.InternalServerError("Database backup failed; nothing was changed.", err)
	}
	if err := updater.Replace(self, newExe); err != nil {
		release()
		return e.InternalServerError("Could not install the new binary.", err)
	}
	e.App.Logger().Info("update installed, restarting", "from", buildinfo.Version, "to", rel.Version, "by", e.Auth.Email())

	// Answer first, then exit: the service manager starts the new binary.
	go func() {
		time.Sleep(time.Second)
		c.opts.Exit()
	}()
	return e.JSON(http.StatusAccepted, map[string]any{"version": rel.Version})
}
