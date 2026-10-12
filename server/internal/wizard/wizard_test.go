package wizard_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"sync"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
	"github.com/Paul-Carouge/Alcove/server/internal/wizard"
)

const token = "preset-setup-token-for-tests"

type env struct {
	t   *testing.T
	app *tests.TestApp
	srv string
}

func setup(t *testing.T) *env {
	t.Helper()
	app := testutil.NewApp(t) // fresh data dir: no administrator yet
	t.Cleanup(app.Cleanup)
	app.Settings().RateLimits.Enabled = false
	wizard.Register(app, config.Config{SetupToken: token})
	return &env{t: t, app: app, srv: testutil.Server(t, app).URL}
}

func (e *env) post(path string, body any) (int, string) {
	e.t.Helper()
	b, _ := json.Marshal(body)
	res, err := http.Post(e.srv+path, "application/json", strings.NewReader(string(b)))
	if err != nil {
		e.t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	raw, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(raw)
}

func admin(email, password string) map[string]any {
	return map[string]any{"token": token, "admin": map[string]any{"name": "Camille", "email": email, "password": password}}
}

func TestStatusChecksTokenAndStorage(t *testing.T) {
	e := setup(t)
	if status, _ := e.post("/api/v1/setup/status", map[string]any{"token": "wrong-token-value"}); status != 403 {
		t.Errorf("wrong token: %d", status)
	}
	status, raw := e.post("/api/v1/setup/status", map[string]any{"token": token})
	if status != 200 || !strings.Contains(raw, `"type":"local"`) || !strings.Contains(raw, `"writable":true`) {
		t.Fatalf("status: %d %s", status, raw)
	}
}

func TestCompleteCreatesAdminAndAppAccountOnce(t *testing.T) {
	e := setup(t)
	for name, body := range map[string]map[string]any{
		"bad token":      {"token": "nope-nope-nope-nope", "admin": map[string]any{"email": "a@b.co", "password": "long-enough-pw"}},
		"bad email":      admin("not-an-email", "long-enough-pw"),
		"short password": admin("camille@example.com", "short"),
	} {
		want := 400
		if name == "bad token" {
			want = 403
		}
		if status, raw := e.post("/api/v1/setup", body); status != want {
			t.Errorf("%s: %d %s", name, status, raw)
		}
	}

	body := admin("camille@example.com", "long-enough-pw")
	body["smtp"] = map[string]any{"host": "smtp.example.com", "port": 587, "username": "u", "password": "p", "senderAddress": "noreply@example.com"}
	if status, raw := e.post("/api/v1/setup", body); status != 204 {
		t.Fatalf("complete: %d %s", status, raw)
	}

	su, err := e.app.FindAuthRecordByEmail(core.CollectionNameSuperusers, "camille@example.com")
	if err != nil || !su.ValidatePassword("long-enough-pw") {
		t.Fatalf("superuser not created: %v", err)
	}
	user, err := e.app.FindAuthRecordByEmail("users", "camille@example.com")
	if err != nil || !user.Verified() || user.GetString("name") != "Camille" || !user.ValidatePassword("long-enough-pw") {
		t.Fatalf("app account not created: %v", err)
	}
	if s := e.app.Settings(); !s.SMTP.Enabled || s.SMTP.Host != "smtp.example.com" || s.Meta.SenderAddress != "noreply@example.com" {
		t.Errorf("SMTP not saved: %+v", s.SMTP)
	}
	if wizard.Required(e.app) {
		t.Error("setup still required")
	}

	if status, _ := e.post("/api/v1/setup", admin("intruder@example.com", "long-enough-pw")); status != 409 {
		t.Errorf("second completion: %d", status)
	}
	if status, _ := e.post("/api/v1/setup/status", map[string]any{"token": token}); status != 409 {
		t.Errorf("status after setup: %d", status)
	}
}

func TestConcurrentCompletionsOnlyOneWins(t *testing.T) {
	e := setup(t)
	var wg sync.WaitGroup
	results := make(chan int, 5)
	for i := range 5 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			status, _ := e.post("/api/v1/setup", admin("racer"+string(rune('a'+i))+"@example.com", "long-enough-pw"))
			results <- status
		}()
	}
	wg.Wait()
	close(results)
	wins := 0
	for s := range results {
		if s == 204 {
			wins++
		}
	}
	n, _ := e.app.CountRecords(core.CollectionNameSuperusers)
	if wins != 1 || n != 1 {
		t.Fatalf("wins=%d superusers=%d, want exactly one", wins, n)
	}
}

func TestSmtpTestReportsFailures(t *testing.T) {
	e := setup(t)
	status, raw := e.post("/api/v1/setup/smtp-test", map[string]any{
		"token": token, "to": "camille@example.com",
		"smtp": map[string]any{"host": "127.0.0.1", "port": 1, "senderAddress": "noreply@example.com"},
	})
	if status != 400 || !strings.Contains(raw, "SMTP server rejected") {
		t.Fatalf("unreachable SMTP: %d %s", status, raw)
	}
}
