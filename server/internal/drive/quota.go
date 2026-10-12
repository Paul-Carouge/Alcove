package drive

import (
	"errors"
	"net/http"

	"github.com/pocketbase/dbx"
	validation "github.com/pocketbase/ozzo-validation/v4"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
)

// ErrQuotaExceeded is returned when a file would not fit in its owner's quota.
var ErrQuotaExceeded = errors.New("quota exceeded")

// quotaCode identifies the validation error sent to API clients.
const quotaCode = "validation_quota_exceeded"

func quotaValidationError() validation.Errors {
	return validation.Errors{"blob": validation.NewError(quotaCode, "Not enough storage space left.")}
}

// Usage is the storage a user consumes, in bytes. Trashed files count until purged.
type Usage struct {
	Used  int64 `json:"used"`
	Trash int64 `json:"trash"`
	Quota int64 `json:"quota"`
}

// UsageOf sums the sizes of the user's files (excluding one node, e.g. the
// file being replaced) and reads their quota.
func UsageOf(app core.App, owner string, excludeNode string) (Usage, error) {
	var row struct {
		Used  int64 `db:"used"`
		Trash int64 `db:"trash"`
	}
	err := app.DB().Select(
		"COALESCE(SUM(size), 0) AS used",
		"COALESCE(SUM(CASE WHEN trashed_at != '' THEN size ELSE 0 END), 0) AS trash",
	).From(Collection).
		Where(dbx.HashExp{"owner": owner}).
		AndWhere(dbx.Not(dbx.HashExp{"id": excludeNode})).
		One(&row)
	if err != nil {
		return Usage{}, err
	}
	user, err := app.FindRecordById("users", owner)
	if err != nil {
		return Usage{}, err
	}
	return Usage{Used: row.Used, Trash: row.Trash, Quota: int64(user.GetInt("quota_bytes"))}, nil
}

// Fits reports whether adding size bytes keeps the user within quota.
func (u Usage) Fits(size int64) bool {
	return u.Quota <= 0 || u.Used+size <= u.Quota
}

// CheckQuota returns ErrQuotaExceeded if size more bytes do not fit.
func CheckQuota(app core.App, owner string, size int64, excludeNode string) error {
	u, err := UsageOf(app, owner, excludeNode)
	if err != nil {
		return err
	}
	if !u.Fits(size) {
		return ErrQuotaExceeded
	}
	return nil
}

// IsQuotaError reports whether err comes from a quota check (directly, or as
// the validation error returned by the drive hooks).
func IsQuotaError(err error) bool {
	if errors.Is(err, ErrQuotaExceeded) {
		return true
	}
	var verrs validation.Errors
	if errors.As(err, &verrs) {
		for _, e := range verrs {
			var ve validation.Error
			if errors.As(e, &ve) && ve.Code() == quotaCode {
				return true
			}
		}
	}
	return false
}

func registerUsage(app core.App) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.GET("/api/v1/me/usage", func(e *core.RequestEvent) error {
			u, err := UsageOf(e.App, e.Auth.Id, "")
			if err != nil {
				return err
			}
			e.Response.Header().Set("Cache-Control", "no-store")
			return e.JSON(http.StatusOK, u)
		}).Bind(apis.RequireAuth("users"))
		return se.Next()
	})
}
