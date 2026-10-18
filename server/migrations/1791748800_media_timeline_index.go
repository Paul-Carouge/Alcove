package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
)

// The timeline sorts by taken_at then id within an owner's media: with id in the index, SQLite reads
// pages in order instead of sorting the whole library (thousands of random reads on a hard disk).
func init() {
	m.Register(func(app core.App) error {
		media, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			return err
		}
		media.RemoveIndex("idx_media_timeline")
		media.AddIndex("idx_media_timeline_id", false, "owner, taken_at, id", "")
		return app.Save(media)
	}, func(app core.App) error {
		media, err := app.FindCollectionByNameOrId("media")
		if err != nil {
			return err
		}
		media.RemoveIndex("idx_media_timeline_id")
		media.AddIndex("idx_media_timeline", false, "owner, taken_at", "")
		return app.Save(media)
	})
}
