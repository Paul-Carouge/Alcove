package uploads_test

import (
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func setQuota(t *testing.T, e *env, bytes int) {
	t.Helper()
	e.alice.Set("quota_bytes", bytes)
	if err := e.app.Save(e.alice); err != nil {
		t.Fatal(err)
	}
}

func TestQuotaRejectsUploadUpFront(t *testing.T) {
	e := setup(t)
	setQuota(t, e, 10)
	res := do(t, http.MethodPost, e.url, e.aliceTok, map[string]string{
		"Upload-Length": "11", "Upload-Metadata": meta("filename", "big.txt"),
	}, "")
	body, _ := io.ReadAll(res.Body)
	if res.StatusCode != http.StatusRequestEntityTooLarge || !strings.HasPrefix(string(body), "ERR_QUOTA_EXCEEDED") {
		t.Fatalf("status %d body %q", res.StatusCode, body)
	}
	e.create(t, e.aliceTok, 10, meta("filename", "fits.txt")) // exactly the quota is fine
}

func TestQuotaRecheckedWhenUploadFinishes(t *testing.T) {
	e := setup(t)
	setQuota(t, e, 15)
	// Two uploads that each fit, but not together.
	first := e.create(t, e.aliceTok, 11, meta("filename", "one.txt"))
	second := e.create(t, e.aliceTok, 11, meta("filename", "two.txt"))
	if res := patch(t, first, e.aliceTok, 0, "hello world"); res.Header.Get("Alcove-Node-Id") == "" {
		t.Fatalf("first upload should complete (status %d)", res.StatusCode)
	}
	res := patch(t, second, e.aliceTok, 0, "hello world")
	body, _ := io.ReadAll(res.Body)
	if res.StatusCode != http.StatusRequestEntityTooLarge || !strings.HasPrefix(string(body), "ERR_QUOTA_EXCEEDED") {
		t.Fatalf("second upload: status %d body %q", res.StatusCode, body)
	}
	entries, _ := os.ReadDir(filepath.Join(e.app.DataDir(), "uploads"))
	if len(entries) != 0 {
		t.Errorf("rejected upload data left behind: %d files", len(entries))
	}
}
