// Package backup makes consistent copies of the main database before updates.
// Files (originals, thumbnails) are not copied: migrations only touch the
// database, and the files stay where they are.
package backup

import (
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/core"
)

const (
	// Dir is the backups folder inside the data directory (pb_data).
	Dir = "alcove_backups"
	// Keep is how many automatic backups are retained.
	Keep = 5
	ext  = ".db"
)

// Database writes an online, consistent copy of data.db (SQLite VACUUM INTO)
// to <pb_data>/alcove_backups/<time>-<label>.db and prunes old ones.
func Database(app core.App, label string) (string, error) {
	dir := filepath.Join(app.DataDir(), Dir)
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return "", err
	}
	name := time.Now().UTC().Format("20060102-150405") + "-" + sanitize(label) + ext
	dest := filepath.Join(dir, name)
	if _, err := app.DB().NewQuery("VACUUM INTO {:dest}").Bind(map[string]any{"dest": dest}).Execute(); err != nil {
		return "", fmt.Errorf("database backup: %w", err)
	}
	if err := os.Chmod(dest, 0o600); err != nil {
		return "", err
	}
	return dest, Prune(dir, Keep)
}

func sanitize(s string) string {
	s = strings.Map(func(r rune) rune {
		if r >= 'a' && r <= 'z' || r >= 'A' && r <= 'Z' || r >= '0' && r <= '9' || r == '.' || r == '-' {
			return r
		}
		return '-'
	}, s)
	if s == "" {
		return "manual"
	}
	return s
}

// List returns backup files, newest first.
func List(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if errors.Is(err, os.ErrNotExist) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	var out []string
	for _, e := range entries {
		if !e.IsDir() && strings.HasSuffix(e.Name(), ext) {
			out = append(out, filepath.Join(dir, e.Name()))
		}
	}
	sort.Sort(sort.Reverse(sort.StringSlice(out))) // names start with a UTC timestamp
	return out, nil
}

// Prune keeps the newest `keep` backups.
func Prune(dir string, keep int) error {
	files, err := List(dir)
	if err != nil {
		return err
	}
	var errs []error
	for _, f := range files[min(keep, len(files)):] {
		if err := os.Remove(f); err != nil {
			errs = append(errs, err)
		}
	}
	return errors.Join(errs...)
}

// Restore replaces <pbData>/data.db with a backup. The server must be stopped.
func Restore(pbData, file string) error {
	src, err := os.ReadFile(file) // #nosec G304 -- backup chosen by the administrator
	if err != nil {
		return err
	}
	db := filepath.Join(pbData, "data.db")
	for _, suffix := range []string{"-wal", "-shm"} {
		if err := os.Remove(db + suffix); err != nil && !errors.Is(err, os.ErrNotExist) {
			return err
		}
	}
	tmp := db + ".restoring"
	if err := os.WriteFile(tmp, src, 0o600); err != nil { // #nosec G703 -- path inside the data dir given by the administrator
		return err
	}
	return os.Rename(tmp, db)
}
