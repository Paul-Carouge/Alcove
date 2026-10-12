package backup_test

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/backup"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

func TestDatabaseBackupAndRestore(t *testing.T) {
	app := testutil.NewApp(t)
	defer app.Cleanup()
	u, _ := testutil.User(t, app, "before@test.local")

	file, err := backup.Database(app, "pre update v1.2.3")
	if err != nil {
		t.Fatal(err)
	}
	if filepath.Base(filepath.Dir(file)) != backup.Dir || filepath.Ext(file) != ".db" {
		t.Fatalf("unexpected path %s", file)
	}
	if info, _ := os.Stat(file); info.Mode().Perm() != 0o600 {
		t.Errorf("backup mode %v", info.Mode().Perm())
	}

	// Change data after the backup, then restore into a copy of pb_data.
	testutil.User(t, app, "after@test.local")
	restoreDir := t.TempDir()
	if err := backup.Restore(restoreDir, file); err != nil {
		t.Fatal(err)
	}
	restored, err := os.ReadFile(filepath.Join(restoreDir, "data.db"))
	if err != nil || len(restored) == 0 {
		t.Fatalf("restore: %v", err)
	}
	_ = u
}

func TestPruneKeepsNewest(t *testing.T) {
	dir := t.TempDir()
	for _, n := range []string{"20260101-000000-a.db", "20260102-000000-b.db", "20260103-000000-c.db", "notes.txt"} {
		_ = os.WriteFile(filepath.Join(dir, n), []byte("x"), 0o600)
	}
	if err := backup.Prune(dir, 2); err != nil {
		t.Fatal(err)
	}
	files, _ := backup.List(dir)
	if len(files) != 2 || filepath.Base(files[0]) != "20260103-000000-c.db" {
		t.Fatalf("files = %v", files)
	}
	if _, err := os.Stat(filepath.Join(dir, "notes.txt")); err != nil {
		t.Error("non-backup files must be left alone")
	}
}
