package takeout

import (
	"encoding/json"
	"errors"
	"io/fs"
	"os"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

const (
	// MaxUploads caps an account's import archives (finished and in progress).
	MaxUploads = 200
	// SettingMaxUploadBytes (app_settings, bytes) caps an account's import archives when it has no quota.
	SettingMaxUploadBytes = "imports.max_upload_bytes"
	defaultMaxUploadBytes = 500_000_000_000
	// tusDir is internal/uploads' folder of partial uploads (that package imports this one).
	tusDir = "uploads"
	// UnusedAfter: an account's archives no job uses are deleted when nothing was uploaded for this long.
	UnusedAfter = 24 * time.Hour
)

var uploadID = regexp.MustCompile(`^[A-Za-z0-9]{1,64}$`)

// StoredUpload is a finished import archive.
type StoredUpload struct {
	ID         string    `json:"id"`
	Name       string    `json:"name"`
	Size       int64     `json:"size"`
	FinishedAt time.Time `json:"finishedAt"`
}

func uploadsOf(app core.App, owner string) string {
	return filepath.Join(app.DataDir(), UploadDir, owner)
}

// StoreUpload moves a finished tus upload into the owner's import archives, with its original name.
func StoreUpload(app core.App, owner, id, name, bin string) error {
	if !uploadID.MatchString(id) {
		return errors.New("invalid upload id")
	}
	dir := uploadsOf(app, owner)
	if err := os.MkdirAll(dir, 0o750); err != nil {
		return err
	}
	meta, _ := json.Marshal(StoredUpload{ID: id, Name: name, FinishedAt: time.Now().UTC()})
	if err := os.WriteFile(filepath.Join(dir, id+".json"), meta, 0o600); err != nil {
		return err
	}
	return os.Rename(bin, filepath.Join(dir, id+".zip"))
}

// ListUploads returns the owner's finished archives, newest first.
func ListUploads(app core.App, owner string) ([]StoredUpload, error) {
	root, err := os.OpenRoot(uploadsOf(app, owner))
	if errors.Is(err, fs.ErrNotExist) {
		return []StoredUpload{}, nil
	}
	if err != nil {
		return nil, err
	}
	defer func() { _ = root.Close() }()
	entries, err := fs.ReadDir(root.FS(), ".")
	if err != nil {
		return nil, err
	}
	out := []StoredUpload{}
	for _, d := range entries {
		id, ok := strings.CutSuffix(d.Name(), ".zip")
		if !ok || !uploadID.MatchString(id) || !d.Type().IsRegular() {
			continue
		}
		info, err := d.Info()
		if err != nil {
			continue
		}
		u := StoredUpload{ID: id, Name: id + ".zip", Size: info.Size(), FinishedAt: info.ModTime().UTC()}
		if b, err := fs.ReadFile(root.FS(), id+".json"); err == nil && len(b) < 4096 {
			var m StoredUpload
			if json.Unmarshal(b, &m) == nil && m.Name != "" {
				u.Name, u.FinishedAt = m.Name, m.FinishedAt
			}
		}
		out = append(out, u)
	}
	slices.SortFunc(out, func(a, b StoredUpload) int { return b.FinishedAt.Compare(a.FinishedAt) })
	return out, nil
}

// DeleteUpload removes one of the owner's archives.
func DeleteUpload(app core.App, owner, id string) error {
	if !uploadID.MatchString(id) {
		return fs.ErrNotExist
	}
	root, err := os.OpenRoot(uploadsOf(app, owner))
	if err != nil {
		return err
	}
	defer func() { _ = root.Close() }()
	if err := root.Remove(id + ".zip"); err != nil {
		return err
	}
	_ = root.Remove(id + ".json")
	return nil
}

// usedUploads are the archives unfinished jobs need ("owner/id").
func usedUploads(app core.App) (map[string]bool, error) {
	jobs, err := app.FindAllRecords(Collection, dbx.HashExp{"source": "upload"}, dbx.In("status", StatusQueued, StatusScanning, StatusRunning))
	if err != nil {
		return nil, err
	}
	used := map[string]bool{}
	for _, j := range jobs {
		for _, f := range j.GetStringSlice("files") {
			used[j.GetString("owner")+"/"+f] = true
		}
	}
	return used, nil
}

// tusUpload is a partial upload of internal/uploads.
type tusUpload struct {
	owner     string
	import_   bool
	size      int64
	remaining int64
	modified  time.Time
}

// partialUploads reads the tus folder (its .info files and data sizes).
func partialUploads(dataDir string) []tusUpload {
	root, err := os.OpenRoot(filepath.Join(dataDir, tusDir))
	if err != nil {
		return nil
	}
	defer func() { _ = root.Close() }()
	entries, _ := fs.ReadDir(root.FS(), ".")
	var out []tusUpload
	for _, d := range entries {
		id, ok := strings.CutSuffix(d.Name(), ".info")
		if !ok || !d.Type().IsRegular() {
			continue
		}
		b, err := fs.ReadFile(root.FS(), d.Name())
		if err != nil || len(b) > 64<<10 {
			continue
		}
		var info struct {
			Size     int64
			MetaData map[string]string
		}
		if json.Unmarshal(b, &info) != nil {
			continue
		}
		u := tusUpload{owner: info.MetaData["owner"], import_: info.MetaData["purpose"] == "import", size: max(info.Size, 0), remaining: max(info.Size, 0)}
		if st, err := root.Stat(id); err == nil {
			u.remaining = max(info.Size-st.Size(), 0)
			u.modified = st.ModTime()
		}
		out = append(out, u)
	}
	return out
}

// ImportUsage counts the owner's import archives, finished and in progress (announced sizes).
func ImportUsage(app core.App, owner string) (int, int64) {
	n, bytes := 0, int64(0)
	if stored, err := ListUploads(app, owner); err == nil {
		for _, u := range stored {
			n, bytes = n+1, satAdd(bytes, u.Size)
		}
	}
	for _, u := range partialUploads(app.DataDir()) {
		if u.import_ && u.owner == owner {
			n, bytes = n+1, satAdd(bytes, u.size)
		}
	}
	return n, bytes
}

// UploadLimit is how many bytes of import archives the owner may keep: what is left of their quota, or
// the server-wide setting (default 500 GB) without quota.
func UploadLimit(app core.App, owner string) int64 {
	if u, err := drive.UsageOf(app, owner, ""); err == nil && u.Quota > 0 {
		return max(u.Quota-u.Used, 0)
	}
	if rec, err := app.FindFirstRecordByFilter("app_settings", "key = {:k}", dbx.Params{"k": SettingMaxUploadBytes}); err == nil {
		var v float64
		if json.Unmarshal([]byte(rec.GetString("value")), &v) == nil && v > 0 {
			return int64(min(v, 1<<62))
		}
	}
	return defaultMaxUploadBytes
}

// ImportFloor stays free during imports and their uploads: 5% of the volume, at least 5 GB.
func ImportFloor(total uint64) uint64 { return max(5_000_000_000, total/20) }

// SafetyFloor stays free for every other upload, so SQLite can always write: 1% of the volume, at least
// 512 MB (small enough for a Raspberry Pi's SD card).
func SafetyFloor(total uint64) uint64 { return max(512<<20, total/100) }

// FitsOnDisk reports whether need more bytes fit on dataDir's volume, counting what partial uploads
// still announce (countPartial) and keeping floor(volume size) free. Unknown free space (exotic file
// systems) passes.
func FitsOnDisk(dataDir string, need int64, countPartial bool, floor func(total uint64) uint64) bool {
	free, total, err := DiskSpace(dataDir)
	if err != nil {
		return true
	}
	var pending int64
	if countPartial {
		for _, u := range partialUploads(dataDir) {
			pending = satAdd(pending, u.remaining)
		}
	}
	return fits(free, total, pending, need, floor)
}

func fits(free, total uint64, pending, need int64, floor func(uint64) uint64) bool {
	avail := int64(min(free, 1<<62)) - int64(min(floor(total), 1<<62)) - pending // #nosec G115 -- bounded
	return need <= avail
}

// removeUnusedUploads deletes, per account, the archives no unfinished job uses, once nothing was
// uploaded for UnusedAfter (someone sending 10 × 50 GB keeps the first ones while sending the others).
func (r *Runner) removeUnusedUploads(now time.Time) error {
	base := filepath.Join(r.app.DataDir(), UploadDir)
	owners, err := os.ReadDir(base)
	if err != nil {
		return nil
	}
	r.mu.Lock() // no job may be created with an archive being deleted
	defer r.mu.Unlock()
	used, err := usedUploads(r.app)
	if err != nil {
		return err
	}
	latest := map[string]time.Time{}
	for _, u := range partialUploads(r.app.DataDir()) {
		if u.import_ && u.modified.After(latest[u.owner]) {
			latest[u.owner] = u.modified
		}
	}
	var errs []error
	for _, o := range owners {
		owner := o.Name()
		if !o.IsDir() || !uploadID.MatchString(owner) {
			continue
		}
		stored, err := ListUploads(r.app, owner)
		if err != nil {
			continue
		}
		newest := latest[owner]
		for _, u := range stored {
			if u.FinishedAt.After(newest) {
				newest = u.FinishedAt
			}
		}
		if now.Sub(newest) < UnusedAfter {
			continue
		}
		for _, u := range stored {
			if !used[owner+"/"+u.ID] {
				if err := DeleteUpload(r.app, owner, u.ID); err != nil {
					errs = append(errs, err)
				}
			}
		}
	}
	return errors.Join(errs...)
}
