// Package notes holds the invariants of the `notes` collection (ADR 0027). Reads and writes go through
// PocketBase's record API and realtime, restricted to the owner by the collection rules.
package notes

import (
	"errors"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

// Module is the name advertised in /health.
const Module = "notes"

const Collection = "notes"

// Register binds the model hooks and the trash purge.
func Register(app core.App) {
	check := func(e *core.RecordEvent) error {
		if err := drive.CheckTags(e.App, e.Record); err != nil {
			return err
		}
		return e.Next()
	}
	app.OnRecordCreate(Collection).BindFunc(check)
	app.OnRecordUpdate(Collection).BindFunc(check)
	app.Cron().MustAdd("alcovePurgeNotes", "40 3 * * *", func() {
		if n, err := PurgeTrash(app, time.Now().Add(-drive.TrashRetention)); err != nil {
			app.Logger().Error("notes trash purge failed", "error", err)
		} else if n > 0 {
			app.Logger().Info("notes trash purged", "notes", n)
		}
	})
}

// PurgeTrash permanently deletes notes trashed before cutoff and returns the count.
func PurgeTrash(app core.App, cutoff time.Time) (int, error) {
	old, err := app.FindRecordsByFilter(Collection, "trashed_at != '' && trashed_at < {:cutoff}", "", 0, 0,
		dbx.Params{"cutoff": cutoff.UTC().Format(types.DefaultDateLayout)})
	if err != nil {
		return 0, err
	}
	var errs []error
	deleted := 0
	for _, n := range old {
		if err := app.Delete(n); err != nil {
			errs = append(errs, err)
			continue
		}
		deleted++
	}
	return deleted, errors.Join(errs...)
}
