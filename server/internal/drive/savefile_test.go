package drive_test

import (
	"sort"
	"sync"
	"testing"

	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

func TestSaveNewFileUnderConcurrency(t *testing.T) {
	f := newFixture(t)
	defer f.app.Cleanup()
	const n = 6
	var wg sync.WaitGroup
	names := make([]string, n)
	errs := make([]error, n)
	for i := range n {
		wg.Add(1)
		go func() {
			defer wg.Done()
			node, err := drive.SaveNewFile(f.app, f.alice.Id, f.docs.Id, "photo.jpg", func() (*filesystem.File, error) {
				return filesystem.NewFileFromBytes([]byte("x"), "photo.jpg")
			})
			errs[i] = err
			if err == nil {
				names[i] = node.GetString("name")
			}
		}()
	}
	wg.Wait()
	for _, err := range errs {
		if err != nil {
			t.Fatalf("save: %v", err)
		}
	}
	sort.Strings(names)
	want := []string{"photo (2).jpg", "photo (3).jpg", "photo (4).jpg", "photo (5).jpg", "photo (6).jpg", "photo.jpg"}
	for i := range want {
		if names[i] != want[i] {
			t.Fatalf("names = %v", names)
		}
	}
}
