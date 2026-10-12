package duplicates

import (
	"net/http"
	"slices"
	"strings"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

// Dismissals is the collection of groups marked as "not duplicates".
const Dismissals = "duplicate_dismissals"

// Register mounts the routes.
func Register(app core.App) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		g := se.Router.Group("/api/v1/photos/duplicates").Bind(apis.RequireAuth("users"))
		g.GET("", list)
		g.POST("/dismiss", dismiss)
		return se.Next()
	})
}

type row struct {
	ID           string  `db:"id" json:"id"`
	CollectionID string  `db:"-" json:"collectionId"`
	Thumb        string  `db:"thumb" json:"thumb"`
	Preview      string  `db:"preview" json:"preview"`
	Node         string  `db:"node" json:"node"`
	Kind         string  `db:"kind" json:"kind"`
	Status       string  `db:"status" json:"status"`
	TakenAt      string  `db:"taken_at" json:"taken_at"`
	Width        int     `db:"width" json:"width"`
	Height       int     `db:"height" json:"height"`
	Duration     float64 `db:"duration" json:"duration"`
	Name         string  `db:"name" json:"name"`
	Size         int64   `db:"size" json:"size"`
	Mime         string  `db:"mime" json:"mime"`
	Created      string  `db:"created" json:"created"`
	SHA256       string  `db:"sha256" json:"-"`
	PHash        string  `db:"phash" json:"-"`
}

// better reports whether a is a better copy to keep than b.
func better(a, b row) bool {
	if pa, pb := a.Width*a.Height, b.Width*b.Height; pa != pb {
		return pa > pb
	}
	if a.Size != b.Size {
		return a.Size > b.Size
	}
	return a.Created < b.Created
}

func list(e *core.RequestEvent) error {
	var rows []row
	err := e.App.DB().Select("m.id", "m.thumb", "m.preview", "m.node", "m.kind", "m.status", "m.taken_at",
		"m.width", "m.height", "m.duration", "m.phash", "n.name", "n.size", "n.mime", "n.created", "n.sha256").
		From("media m").
		InnerJoin("nodes n", dbx.NewExp("n.id = m.node")).
		Where(dbx.HashExp{"m.owner": e.Auth.Id}).
		AndWhere(dbx.NewExp("n.trashed_at = ''")).
		OrderBy("m.taken_at DESC", "m.id DESC").
		All(&rows)
	if err != nil {
		return err
	}
	items := make([]Item, len(rows))
	for i, r := range rows {
		items[i] = Item{ID: r.ID, SHA256: r.SHA256, PHash: r.PHash, Image: r.Kind == "image"}
	}

	dismissed, err := e.App.FindAllRecords(Dismissals, dbx.HashExp{"owner": e.Auth.Id})
	if err != nil {
		return err
	}
	cid := ""
	if c, err := e.App.FindCachedCollectionByNameOrId("media"); err == nil {
		cid = c.Id
	}
	groups := []map[string]any{}
	for _, set := range Group(items) {
		members := make([]row, len(set))
		ids := make([]string, len(set))
		identical := true
		for i, idx := range set {
			members[i] = rows[idx]
			members[i].CollectionID = cid
			ids[i] = rows[idx].ID
			identical = identical && rows[idx].SHA256 != "" && rows[idx].SHA256 == rows[set[0]].SHA256
		}
		if isDismissed(dismissed, ids) {
			continue
		}
		keep := members[0]
		for _, m := range members[1:] {
			if better(m, keep) {
				keep = m
			}
		}
		kind := "similar"
		if identical {
			kind = "identical"
		}
		groups = append(groups, map[string]any{"kind": kind, "keep": keep.ID, "items": members})
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, map[string]any{"groups": groups})
}

// isDismissed reports whether every id is in one dismissed group (a new similar photo shows it again).
func isDismissed(dismissed []*core.Record, ids []string) bool {
	for _, d := range dismissed {
		known := d.GetStringSlice("items")
		if !slices.ContainsFunc(ids, func(id string) bool { return !slices.Contains(known, id) }) {
			return true
		}
	}
	return false
}

func dismiss(e *core.RequestEvent) error {
	var body struct {
		Items []string `json:"items"`
	}
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("Invalid body.", err)
	}
	ids := slices.Compact(slices.Sorted(slices.Values(body.Items)))
	if len(ids) < 2 || len(ids) > 1000 {
		return e.BadRequestError("Give 2 to 1000 items.", nil)
	}
	owned, err := e.App.FindRecordsByIds("media", ids, func(q *dbx.SelectQuery) error {
		q.AndWhere(dbx.HashExp{"owner": e.Auth.Id})
		return nil
	})
	if err != nil || len(owned) != len(ids) {
		return e.BadRequestError("Unknown items: "+strings.Join(missing(ids, owned), ", "), nil)
	}
	col, err := e.App.FindCollectionByNameOrId(Dismissals)
	if err != nil {
		return err
	}
	rec := core.NewRecord(col)
	rec.Set("owner", e.Auth.Id)
	rec.Set("items", ids)
	if err := e.App.Save(rec); err != nil {
		return err
	}
	return e.NoContent(http.StatusNoContent)
}

func missing(ids []string, found []*core.Record) []string {
	var out []string
	for _, id := range ids {
		if !slices.ContainsFunc(found, func(r *core.Record) bool { return r.Id == id }) {
			out = append(out, id)
		}
	}
	if len(out) > 5 {
		out = append(out[:5], "…")
	}
	return out
}
