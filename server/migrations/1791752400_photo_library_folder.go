package migrations

import (
	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

// photoLibrary is the root folder grouping the photo library apart from the rest of the drive.
const photoLibrary = "Photos"

// photoSources are the root folders the photo features created before 0.34, lower-cased: Google Takeout
// imports and the mobile backup (its default name in English and French). Drive names ignore case.
var photoSources = []any{"google photos", "phone backup", "sauvegarde du téléphone"}

// The photo library moves into one "Photos" root folder, so the drive root keeps the user's own files.
// Mobile apps keep backing up into their folder: they find it by id.
func init() {
	m.Register(func(app core.App) error {
		var recs []*core.Record
		err := app.RecordQuery("nodes").
			AndWhere(dbx.NewExp("parent = '' AND kind = 'folder' AND trashed_at = ''")).
			AndWhere(dbx.In("LOWER(name)", photoSources...)).
			All(&recs)
		if err != nil {
			return err
		}
		// One library per owner, even when a file named "Photos" makes EnsureFolder pick "Photos (2)".
		libraries := map[string]string{}
		for _, rec := range recs {
			owner := rec.GetString("owner")
			photos, ok := libraries[owner]
			if !ok {
				if photos, err = drive.EnsureFolder(app, owner, "", photoLibrary); err != nil {
					return err
				}
				libraries[owner] = photos
			}
			if err := moveFolder(app, rec, photos); err != nil {
				return err
			}
		}
		return nil
	}, func(app core.App) error {
		// The "Photos" folders stay: the user may have made them. Sources renamed by up ("Google Photos (2)")
		// stay in them.
		var recs []*core.Record
		err := app.RecordQuery("nodes").
			AndWhere(dbx.NewExp("kind = 'folder' AND trashed_at = '' AND parent IN " +
				"(SELECT id FROM nodes WHERE parent = '' AND kind = 'folder' AND trashed_at = '' AND LOWER(name) = 'photos')")).
			AndWhere(dbx.In("LOWER(name)", photoSources...)).
			All(&recs)
		if err != nil {
			return err
		}
		for _, rec := range recs {
			if err := moveFolder(app, rec, ""); err != nil {
				return err
			}
		}
		return nil
	})
}

func moveFolder(app core.App, rec *core.Record, parent string) error {
	name, err := drive.AvailableName(app, rec.GetString("owner"), parent, rec.GetString("name"))
	if err != nil {
		return err
	}
	rec.Set("parent", parent)
	rec.Set("name", name)
	return app.Save(rec)
}
