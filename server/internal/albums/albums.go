// Package albums adds what collection rules cannot express for albums (ADR 0018): consistency
// hooks, and reads with counts, covers, file names and people.
package albums

import (
	"cmp"
	"errors"
	"net/http"
	"slices"
	"strconv"
	"strings"

	"github.com/pocketbase/dbx"
	validation "github.com/pocketbase/ozzo-validation/v4"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

const (
	Collection = "albums"
	Items      = "album_items"

	RoleOwner       = "owner"
	RoleContributor = "contributor"
	RoleViewer      = "viewer"
)

// Register binds hooks and routes.
func Register(app core.App) {
	app.OnRecordCreate(Collection).BindFunc(func(e *core.RecordEvent) error {
		if err := normalize(e.App, e.Record, true); err != nil {
			return err
		}
		return e.Next()
	})
	app.OnRecordUpdate(Collection).BindFunc(func(e *core.RecordEvent) error {
		if err := normalize(e.App, e.Record, false); err != nil {
			return err
		}
		return e.Next()
	})
	app.OnRecordAfterUpdateSuccess(Collection).BindFunc(func(e *core.RecordEvent) error {
		if err := e.Next(); err != nil {
			return err
		}
		prune(e.App, e.Record)
		return nil
	})
	app.OnRecordAfterCreateSuccess(Items).BindFunc(func(e *core.RecordEvent) error {
		if err := e.Next(); err != nil {
			return err
		}
		touch(e.App, e.Record.GetString("album"), "")
		return nil
	})
	app.OnRecordAfterDeleteSuccess(Items).BindFunc(func(e *core.RecordEvent) error {
		if err := e.Next(); err != nil {
			return err
		}
		touch(e.App, e.Record.GetString("album"), e.Record.GetString("media"))
		return nil
	})

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		g := se.Router.Group("/api/v1").Bind(apis.RequireAuth("users"))
		g.GET("/albums", list)
		g.GET("/albums/{id}/items", items)
		g.GET("/albums/{id}/people", people)
		g.POST("/albums/{id}/leave", leave)
		g.GET("/users/lookup", lookup)
		return se.Next()
	})
}

// RoleOf returns the role of user in album, or "" when it does not take part.
func RoleOf(album *core.Record, user string) string {
	switch {
	case album.GetString("owner") == user:
		return RoleOwner
	case slices.Contains(album.GetStringSlice("contributors"), user):
		return RoleContributor
	case slices.Contains(album.GetStringSlice("members"), user):
		return RoleViewer
	}
	return ""
}

// normalize keeps each person in one role (contributor wins), never the owner, and checks the cover.
func normalize(app core.App, album *core.Record, isNew bool) error {
	owner := album.GetString("owner")
	contributors := slices.DeleteFunc(slices.Compact(slices.Sorted(slices.Values(album.GetStringSlice("contributors")))),
		func(id string) bool { return id == owner })
	members := slices.DeleteFunc(slices.Compact(slices.Sorted(slices.Values(album.GetStringSlice("members")))),
		func(id string) bool { return id == owner || slices.Contains(contributors, id) })
	album.Set("contributors", contributors)
	album.Set("members", members)

	if cover := album.GetString("cover"); cover != "" {
		if isNew || !hasItem(app, album.Id, cover) {
			return validation.Errors{"cover": validation.NewError("validation_cover_not_in_album", "The cover must be a photo of the album.")}
		}
	}
	return nil
}

func hasItem(app core.App, album, media string) bool {
	_, err := app.FindFirstRecordByFilter(Items, "album = {:a} && media = {:m}", dbx.Params{"a": album, "m": media})
	return err == nil
}

// prune removes the photos of people who no longer contribute to the album.
func prune(app core.App, album *core.Record) {
	keep := append([]string{album.GetString("owner")}, album.GetStringSlice("contributors")...)
	recs, err := app.FindAllRecords(Items, dbx.HashExp{"album": album.Id})
	if err != nil {
		return
	}
	for _, r := range recs {
		if !slices.Contains(keep, r.GetString("added_by")) {
			if err := app.Delete(r); err != nil {
				app.Logger().Error("cannot remove album item", "item", r.Id, "error", err)
			}
		}
	}
}

// touch bumps the album's "updated" (sort order, realtime) and drops a cover that left the album.
func touch(app core.App, albumID, removedMedia string) {
	album, err := app.FindRecordById(Collection, albumID)
	if err != nil {
		return // the album itself is being deleted
	}
	if removedMedia != "" && album.GetString("cover") == removedMedia {
		album.Set("cover", "")
	}
	if err := app.Save(album); err != nil {
		app.Logger().Error("cannot update album", "album", albumID, "error", err)
	}
}

// visible returns the album if the caller takes part in it.
func visible(e *core.RequestEvent) (*core.Record, string, error) {
	album, err := e.App.FindRecordById(Collection, e.Request.PathValue("id"))
	if err != nil {
		return nil, "", e.NotFoundError("", nil)
	}
	role := RoleOf(album, e.Auth.Id)
	if role == "" {
		return nil, "", e.NotFoundError("", nil)
	}
	return album, role, nil
}

type mediaFiles struct {
	ID           string `db:"id" json:"id"`
	CollectionID string `db:"-" json:"collectionId"`
	Thumb        string `db:"thumb" json:"thumb"`
	Preview      string `db:"preview" json:"preview"`
}

type item struct {
	mediaFiles
	ItemID      string  `db:"itemId" json:"itemId"`
	AddedBy     string  `db:"addedBy" json:"addedBy"`
	Kind        string  `db:"kind" json:"kind"`
	Status      string  `db:"status" json:"status"`
	TakenAt     string  `db:"taken_at" json:"taken_at"`
	Width       int     `db:"width" json:"width"`
	Height      int     `db:"height" json:"height"`
	Duration    float64 `db:"duration" json:"duration"`
	Favorite    bool    `db:"favorite" json:"favorite"`
	CameraMake  string  `db:"camera_make" json:"camera_make"`
	CameraModel string  `db:"camera_model" json:"camera_model"`
	Lens        string  `db:"lens" json:"lens"`
	Exposure    string  `db:"exposure" json:"exposure"`
	HasLocation bool    `db:"has_location" json:"has_location"`
	Lat         float64 `db:"lat" json:"lat"`
	Lon         float64 `db:"lon" json:"lon"`
	Name        string  `db:"name" json:"name"`
	Size        int64   `db:"size" json:"size"`
	Mime        string  `db:"mime" json:"mime"`
}

// visibleItems selects the album's items whose file is not in the trash.
func visibleItems(app core.App, album string) *dbx.SelectQuery {
	return app.DB().Select().
		From(Items+" ai").
		InnerJoin("media m", dbx.NewExp("m.id = ai.media")).
		InnerJoin("nodes n", dbx.NewExp("n.id = m.node")).
		Where(dbx.HashExp{"ai.album": album}).
		AndWhere(dbx.NewExp("n.trashed_at = ''"))
}

func mediaCollectionID(app core.App) string {
	if c, err := app.FindCachedCollectionByNameOrId("media"); err == nil {
		return c.Id
	}
	return ""
}

func items(e *core.RequestEvent) error {
	album, _, err := visible(e)
	if err != nil {
		return err
	}
	page, perPage := intParam(e, "page", 1, 1, 1<<20), intParam(e, "perPage", 200, 1, 500)
	var total int
	if err := visibleItems(e.App, album.Id).Select("COUNT(*)").Row(&total); err != nil {
		return err
	}
	out := []item{}
	err = visibleItems(e.App, album.Id).
		Select("ai.id AS itemId", "ai.added_by AS addedBy", "m.id", "m.thumb", "m.preview", "m.kind", "m.status",
			"m.taken_at", "m.width", "m.height", "m.duration", "m.camera_make", "m.camera_model", "m.lens",
			"m.exposure", "m.has_location", "m.lat", "m.lon", "n.name", "n.size", "n.mime").
		AndSelect("(m.owner = {:u} AND m.favorite) AS favorite").
		Bind(dbx.Params{"u": e.Auth.Id}).
		OrderBy("m.taken_at DESC", "m.id DESC").
		Offset(int64((page - 1) * perPage)).Limit(int64(perPage)).
		All(&out)
	if err != nil {
		return err
	}
	cid := mediaCollectionID(e.App)
	for i := range out {
		out[i].CollectionID = cid
	}
	return e.JSON(http.StatusOK, map[string]any{"page": page, "perPage": perPage, "totalItems": total, "items": out})
}

func intParam(e *core.RequestEvent, name string, def, lo, hi int) int {
	v, err := strconv.Atoi(e.Request.URL.Query().Get(name))
	if err != nil {
		return def
	}
	return min(max(v, lo), hi)
}

func list(e *core.RequestEvent) error {
	recs, err := e.App.FindRecordsByFilter(Collection,
		"owner = {:u} || members.id ?= {:u} || contributors.id ?= {:u}", "-updated", 0, 0, dbx.Params{"u": e.Auth.Id})
	if err != nil {
		return err
	}
	cid := mediaCollectionID(e.App)
	names := map[string]string{}
	out := make([]map[string]any, 0, len(recs))
	for _, a := range recs {
		var count int
		_ = visibleItems(e.App, a.Id).Select("COUNT(*)").Row(&count)
		owner := a.GetString("owner")
		if _, ok := names[owner]; !ok {
			if u, err := e.App.FindRecordById("users", owner); err == nil {
				names[owner] = cmp.Or(u.GetString("name"), u.Email())
			}
		}
		var cover any
		if f, ok := coverOf(e.App, a); ok {
			f.CollectionID = cid
			cover = f
		}
		out = append(out, map[string]any{
			"id": a.Id, "name": a.GetString("name"), "role": RoleOf(a, e.Auth.Id),
			"owner":  map[string]any{"id": owner, "name": names[owner]},
			"count":  count,
			"shared": len(a.GetStringSlice("members"))+len(a.GetStringSlice("contributors")) > 0,
			"cover":  cover, "updated": a.GetDateTime("updated"),
		})
	}
	return e.JSON(http.StatusOK, map[string]any{"items": out})
}

// coverOf is the chosen cover, or the newest item when there is none or it is in the trash.
func coverOf(app core.App, album *core.Record) (mediaFiles, bool) {
	var f mediaFiles
	pick := visibleItems(app, album.Id).Select("m.id", "m.thumb", "m.preview")
	if c := album.GetString("cover"); c != "" {
		if err := pick.AndWhere(dbx.HashExp{"m.id": c}).One(&f); err == nil {
			return f, true
		}
	}
	err := visibleItems(app, album.Id).Select("m.id", "m.thumb", "m.preview").
		OrderBy("m.taken_at DESC", "m.id DESC").Limit(1).One(&f)
	return f, err == nil
}

type person struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
	Role  string `json:"role,omitempty"`
}

func personOf(u *core.Record, role string) person {
	return person{ID: u.Id, Name: u.GetString("name"), Email: u.Email(), Role: role}
}

func people(e *core.RequestEvent) error {
	album, _, err := visible(e)
	if err != nil {
		return err
	}
	owner, err := e.App.FindRecordById("users", album.GetString("owner"))
	if err != nil {
		return err
	}
	out := []person{}
	for _, group := range []struct {
		field, role string
	}{{"contributors", RoleContributor}, {"members", RoleViewer}} {
		users, err := e.App.FindRecordsByIds("users", album.GetStringSlice(group.field))
		if err != nil {
			return err
		}
		for _, u := range users {
			out = append(out, personOf(u, group.role))
		}
	}
	slices.SortFunc(out, func(a, b person) int { return strings.Compare(a.Email, b.Email) })
	return e.JSON(http.StatusOK, map[string]any{"owner": personOf(owner, ""), "people": out})
}

func leave(e *core.RequestEvent) error {
	album, role, err := visible(e)
	if err != nil {
		return err
	}
	if role == RoleOwner {
		return e.BadRequestError("The owner cannot leave their own album.", nil)
	}
	drop := func(ids []string) []string {
		return slices.DeleteFunc(ids, func(id string) bool { return id == e.Auth.Id })
	}
	album.Set("members", drop(album.GetStringSlice("members")))
	album.Set("contributors", drop(album.GetStringSlice("contributors")))
	if err := e.App.Save(album); err != nil {
		return err
	}
	return e.NoContent(http.StatusNoContent)
}

var errInvalidEmail = errors.New("a valid email is required")

func lookup(e *core.RequestEvent) error {
	email := strings.TrimSpace(e.Request.URL.Query().Get("email"))
	if len(email) > 254 || !strings.Contains(email, "@") {
		return e.BadRequestError(errInvalidEmail.Error(), nil)
	}
	u := &core.Record{}
	err := e.App.RecordQuery("users").
		AndWhere(dbx.NewExp("email = {:email} COLLATE NOCASE", dbx.Params{"email": email})).
		Limit(1).One(u)
	if err != nil || u.Id == e.Auth.Id {
		return e.NotFoundError("", nil)
	}
	return e.JSON(http.StatusOK, personOf(u, ""))
}
