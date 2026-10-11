// Package drive implements server-side invariants of the file tree stored in
// the "nodes" collection (see migrations/1791684000_drive_nodes.go).
package drive

import (
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"io"
	"path"
	"regexp"
	"strings"
	"time"
	"unicode/utf8"

	"github.com/gabriel-vasile/mimetype"
	"github.com/pocketbase/dbx"
	validation "github.com/pocketbase/ozzo-validation/v4"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/types"
)

// Module is the name advertised in /health when the drive is available.
const Module = "drive"

const (
	Collection = "nodes"
	KindFile   = "file"
	KindFolder = "folder"

	// TrashRetention: trashed nodes older than this are deleted for good.
	TrashRetention = 30 * 24 * time.Hour

	// maxDepth bounds ancestor walks (cycle detection) on corrupted data.
	maxDepth = 1000

	// MaxFileSize caps a single file (also the blob field limit).
	MaxFileSize int64 = 64 << 30

	// NamePattern: 1-255 chars, no "/" or control characters, not only dots.
	NamePattern = `^(?:[^/\x00-\x1f\x7f]*[^/\x00-\x1f\x7f.][^/\x00-\x1f\x7f]*)$`
	NameMaxLen  = 255
)

var nameRe = regexp.MustCompile(NamePattern)

// ValidName reports whether name is acceptable for a node.
func ValidName(name string) bool {
	return name != "" && utf8.RuneCountInString(name) <= NameMaxLen && nameRe.MatchString(name)
}

// AvailableName returns name, or "name (2).ext", "name (3).ext"… if a
// non-trashed sibling already uses it (case-insensitively).
func AvailableName(app core.App, owner, parent, name string) (string, error) {
	ext := path.Ext(name)
	base := strings.TrimSuffix(name, ext)
	if base == "" { // ".bashrc": the whole name is the base
		base, ext = name, ""
	}
	candidate := name
	for i := 2; i < 1000; i++ {
		n, err := app.CountRecords(Collection, dbx.NewExp(
			"owner = {:owner} AND parent = {:parent} AND trashed_at = '' AND name = {:name} COLLATE NOCASE",
			dbx.Params{"owner": owner, "parent": parent, "name": candidate},
		))
		if err != nil {
			return "", err
		}
		if n == 0 {
			return candidate, nil
		}
		candidate = fmt.Sprintf("%s (%d)%s", base, i, ext)
	}
	return "", errors.New("no available name")
}

// Register binds the model hooks. They run for every write (API, admin UI,
// internal code), before the record is persisted.
func Register(app core.App) {
	app.OnRecordCreate(Collection).BindFunc(func(e *core.RecordEvent) error {
		if err := beforeSave(e.App, e.Record); err != nil {
			return err
		}
		return e.Next()
	})
	app.OnRecordUpdate(Collection).BindFunc(func(e *core.RecordEvent) error {
		if err := beforeSave(e.App, e.Record); err != nil {
			return err
		}
		return e.Next()
	})
	registerDownload(app)
	app.Cron().MustAdd("alcovePurgeTrash", "30 3 * * *", func() {
		if n, err := PurgeTrash(app, time.Now().Add(-TrashRetention)); err != nil {
			app.Logger().Error("trash purge failed", "error", err)
		} else if n > 0 {
			app.Logger().Info("trash purged", "nodes", n)
		}
	})
}

// PurgeTrash permanently deletes nodes trashed before cutoff (children go
// with them through the cascading parent relation) and returns the count.
func PurgeTrash(app core.App, cutoff time.Time) (int, error) {
	old, err := app.FindRecordsByFilter(Collection, "trashed_at != '' && trashed_at < {:cutoff}", "", 0, 0,
		dbx.Params{"cutoff": cutoff.UTC().Format(types.DefaultDateLayout)})
	if err != nil {
		return 0, err
	}
	var errs []error
	deleted := 0
	for _, node := range old {
		if err := app.Delete(node); err != nil {
			errs = append(errs, err)
			continue
		}
		deleted++
	}
	return deleted, errors.Join(errs...)
}

func beforeSave(app core.App, node *core.Record) error {
	files := node.GetUnsavedFiles("blob")

	if node.GetString("kind") == KindFolder {
		if len(files) > 0 || node.GetString("blob") != "" {
			return validation.Errors{"blob": validation.NewError("validation_folder_blob", "Folders cannot contain file data.")}
		}
		node.Set("size", 0)
		node.Set("mime", "")
		node.Set("sha256", "")
	}

	if len(files) > 0 {
		meta, err := inspect(files[0].Reader)
		if err != nil {
			return fmt.Errorf("inspect uploaded file: %w", err)
		}
		node.Set("size", meta.size)
		node.Set("mime", meta.mime)
		node.Set("sha256", meta.sha256)
	}

	if !node.IsNew() && node.Original().GetString("parent") != node.GetString("parent") {
		return checkNoCycle(app, node)
	}
	return nil
}

type fileMeta struct {
	size   int64
	mime   string
	sha256 string
}

// inspect streams the file once to compute its size and hash, and sniffs its
// type from content (the client-declared type is never trusted).
func inspect(r interface {
	Open() (io.ReadSeekCloser, error)
}) (fileMeta, error) {
	f, err := r.Open()
	if err != nil {
		return fileMeta{}, err
	}
	defer func() { _ = f.Close() }()

	mt, err := mimetype.DetectReader(f)
	if err != nil {
		return fileMeta{}, err
	}
	if _, err := f.Seek(0, io.SeekStart); err != nil {
		return fileMeta{}, err
	}
	h := sha256.New()
	n, err := io.Copy(h, f)
	if err != nil {
		return fileMeta{}, err
	}
	return fileMeta{size: n, mime: mt.String(), sha256: hex.EncodeToString(h.Sum(nil))}, nil
}

var errCycle = validation.Errors{"parent": validation.NewError("validation_parent_cycle", "A folder cannot be moved inside itself.")}

// checkNoCycle rejects moving a node under itself or one of its descendants.
func checkNoCycle(app core.App, node *core.Record) error {
	id := node.GetString("parent")
	for range maxDepth {
		if id == "" {
			return nil
		}
		if id == node.Id {
			return errCycle
		}
		parent, err := app.FindRecordById(Collection, id)
		if err != nil {
			return errors.Join(errCycle, err)
		}
		id = parent.GetString("parent")
	}
	return errCycle
}
