package appdist

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestPruneKeepsCurrentVersion(t *testing.T) {
	d := &Dist{version: "0.19.0", dir: t.TempDir()}
	for _, name := range []string{"alcove-android-0.18.1.apk", "alcove-android-0.19.0.apk.part", "alcove-android-0.19.0.apk", "alcove-android-0.19.0-arm64-v8a.apk", "alcove-android-0.18.1-arm64-v8a.apk", "other.txt"} {
		if err := os.WriteFile(filepath.Join(d.dir, name), []byte("x"), 0o600); err != nil {
			t.Fatal(err)
		}
	}
	d.prune()
	entries, _ := os.ReadDir(d.dir)
	var left []string
	for _, e := range entries {
		left = append(left, e.Name())
	}
	if strings.Join(left, ",") != "alcove-android-0.19.0-arm64-v8a.apk,alcove-android-0.19.0.apk,other.txt" {
		t.Fatalf("left %v", left)
	}
}
