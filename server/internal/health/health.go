// Package health implements GET /health (see packages/api-spec/openapi.yaml).
package health

import (
	"net/http"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
)

const Path = "/health"

type APIRange struct {
	Min int `json:"min"`
	Max int `json:"max"`
}

type Response struct {
	Status        string   `json:"status"`
	Name          string   `json:"name"`
	Version       string   `json:"version"`
	API           APIRange `json:"api"`
	Modules       []string `json:"modules"`
	SetupRequired bool     `json:"setupRequired"`
}

// Register binds the route. activeModules must not include "core".
// dynamic modules are asked on every request (e.g. documents, active once its tools are installed).
func Register(app core.App, activeModules []string, dynamic ...func() []string) {
	static := append([]string{"core"}, activeModules...)

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.GET(Path, func(e *core.RequestEvent) error {
			e.Response.Header().Set("Cache-Control", "no-store")
			modules := append([]string{}, static...)
			for _, f := range dynamic {
				modules = append(modules, f()...)
			}
			return e.JSON(http.StatusOK, Response{
				Status:        "ok",
				Name:          buildinfo.Name,
				Version:       buildinfo.Version,
				API:           APIRange{Min: buildinfo.APIMin, Max: buildinfo.APIMax},
				Modules:       modules,
				SetupRequired: setupRequired(e.App),
			})
		})
		return se.Next()
	})
}

// setupRequired reports whether no real superuser exists yet (PocketBase
// creates a placeholder installer account on first start).
func setupRequired(app core.App) bool {
	n, err := app.CountRecords(core.CollectionNameSuperusers,
		dbx.Not(dbx.HashExp{"email": core.DefaultInstallerEmail}))
	return err == nil && n == 0
}
