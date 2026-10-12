package media

import (
	"net/http"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
)

type yearFacet struct {
	Year  int `db:"year" json:"year"`
	Count int `db:"count" json:"count"`
}

type cameraFacet struct {
	Make  string `db:"camera_make" json:"make"`
	Model string `db:"camera_model" json:"model"`
	Count int    `db:"count" json:"count"`
}

// facets lists the years and cameras of the caller's photos, for the timeline filters.
func facets(e *core.RequestEvent) error {
	base := func() *dbx.SelectQuery {
		return e.App.DB().Select().From(Collection+" m").
			InnerJoin("nodes n", dbx.NewExp("n.id = m.node")).
			Where(dbx.HashExp{"m.owner": e.Auth.Id}).
			AndWhere(dbx.NewExp("n.trashed_at = ''"))
	}
	years := []yearFacet{}
	if err := base().Select("CAST(substr(m.taken_at, 1, 4) AS INTEGER) AS year", "COUNT(*) AS count").
		AndWhere(dbx.NewExp("m.taken_at != ''")).
		GroupBy("year").OrderBy("year DESC").All(&years); err != nil {
		return err
	}
	cameras := []cameraFacet{}
	if err := base().Select("m.camera_make", "m.camera_model", "COUNT(*) AS count").
		AndWhere(dbx.NewExp("m.camera_model != ''")).
		GroupBy("m.camera_make", "m.camera_model").OrderBy("count DESC").Limit(50).All(&cameras); err != nil {
		return err
	}
	var located int
	if err := base().Select("COUNT(*)").AndWhere(dbx.HashExp{"m.has_location": true}).Row(&located); err != nil {
		return err
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, map[string]any{"years": years, "cameras": cameras, "withLocation": located})
}
