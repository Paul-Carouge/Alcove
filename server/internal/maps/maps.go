// Package maps holds the map settings (ADR 0020): the built-in offline basemap by default, and
// OpenStreetMap tiles when an administrator enables them.
package maps

import (
	"net/http"
	"sync/atomic"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

const (
	settings = "app_settings"
	key      = "map.osm"

	// OSMOrigin is allowed in the CSP img-src only while tiles are enabled.
	OSMOrigin   = "https://tile.openstreetmap.org"
	osmURL      = OSMOrigin + "/{z}/{x}/{y}.png"
	attribution = `© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors`
)

// Maps keeps the current setting in memory: the CSP reads it on every request.
type Maps struct {
	osm atomic.Bool
}

// Register loads the setting and mounts the routes.
func Register(app core.App) *Maps {
	m := &Maps{}
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		m.osm.Store(load(se.App))
		se.Router.GET("/api/v1/map/config", m.config).Bind(apis.RequireAuth("users"))
		se.Router.PUT("/api/v1/admin/map", m.set).Bind(apis.RequireAuth("users"))
		return se.Next()
	})
	return m
}

// ExtraImgSrc returns the tile origin to allow in the CSP, or "".
func (m *Maps) ExtraImgSrc() string {
	if m != nil && m.osm.Load() {
		return OSMOrigin
	}
	return ""
}

func load(app core.App) bool {
	rec, err := app.FindFirstRecordByFilter(settings, "key = {:k}", dbx.Params{"k": key})
	if err != nil {
		return false
	}
	var on bool
	_ = rec.UnmarshalJSONField("value", &on)
	return on
}

func (m *Maps) payload() map[string]any {
	if !m.osm.Load() {
		return map[string]any{"tiles": nil}
	}
	return map[string]any{"tiles": map[string]any{"url": osmURL, "attribution": attribution, "maxZoom": 19}}
}

func (m *Maps) config(e *core.RequestEvent) error {
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, m.payload())
}

func (m *Maps) set(e *core.RequestEvent) error {
	if e.Auth.GetString("role") != "admin" {
		return e.ForbiddenError("Administrators only.", nil)
	}
	var body struct {
		OSM *bool `json:"osm"`
	}
	if err := e.BindBody(&body); err != nil || body.OSM == nil {
		return e.BadRequestError("osm (boolean) is required.", nil)
	}
	rec, err := e.App.FindFirstRecordByFilter(settings, "key = {:k}", dbx.Params{"k": key})
	if err != nil {
		col, cerr := e.App.FindCollectionByNameOrId(settings)
		if cerr != nil {
			return cerr
		}
		rec = core.NewRecord(col)
		rec.Set("key", key)
	}
	rec.Set("value", *body.OSM)
	if err := e.App.Save(rec); err != nil {
		return err
	}
	m.osm.Store(*body.OSM)
	e.App.Logger().Info("map tiles changed", "osm", *body.OSM, "by", e.Auth.Email())
	return e.JSON(http.StatusOK, m.payload())
}
