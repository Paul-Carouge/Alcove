package drive

import (
	"net/http"
	"regexp"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

func registerKnown(app core.App) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.POST("/api/v1/backup/known", known).Bind(apis.RequireAuth("users"))
		return se.Next()
	})
}

var sha256Hex = regexp.MustCompile(`^[a-f0-9]{64}$`)

// known answers which file fingerprints the caller already has (phone backup deduplication). Trashed
// files count: a photo deleted on the server is not brought back by the phone.
func known(e *core.RequestEvent) error {
	var body struct {
		Hashes []string `json:"hashes"`
	}
	if err := e.BindBody(&body); err != nil || len(body.Hashes) > 1000 {
		return e.BadRequestError("Give up to 1000 SHA-256 hashes.", nil)
	}
	hashes := make([]any, 0, len(body.Hashes))
	for _, h := range body.Hashes {
		if !sha256Hex.MatchString(h) {
			return e.BadRequestError("Invalid hash.", nil)
		}
		hashes = append(hashes, h)
	}
	out := []string{}
	if len(hashes) > 0 {
		err := e.App.DB().Select("sha256").Distinct(true).From(Collection).
			Where(dbx.HashExp{"owner": e.Auth.Id, "kind": KindFile}).
			AndWhere(dbx.In("sha256", hashes...)).
			Column(&out)
		if err != nil {
			return err
		}
	}
	return e.JSON(http.StatusOK, map[string]any{"known": out})
}
