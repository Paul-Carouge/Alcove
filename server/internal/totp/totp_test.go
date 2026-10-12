package totp_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pquerna/otp"
	pqtotp "github.com/pquerna/otp/totp"

	"github.com/Paul-Carouge/Alcove/server/internal/secrets"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
	"github.com/Paul-Carouge/Alcove/server/internal/totp"
)

const password = "test-password-123" // testutil.User's password

type env struct {
	t     *testing.T
	app   *tests.TestApp
	srv   string
	user  *core.Record
	token string
	start time.Time
}

func setup(t *testing.T) *env {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	totp.Register(app, secrets.New(app, ""))
	// These tests sign in many times in a row; production limits stay on.
	app.Settings().RateLimits.Enabled = false
	e := &env{t: t, app: app, start: time.Unix(1_900_000_020, 0)}
	e.user, e.token = testutil.User(t, app, "alice@test.local")
	e.srv = testutil.Server(t, app).URL
	t.Cleanup(totp.SetClock(e.start))
	return e
}

// at moves the server clock n 30-second steps after the start.
func (e *env) at(n int) time.Time {
	now := e.start.Add(time.Duration(n) * 30 * time.Second)
	totp.SetClock(now)
	return now
}

func code(t *testing.T, secret string, at time.Time) string {
	t.Helper()
	c, err := pqtotp.GenerateCodeCustom(secret, at, pqtotp.ValidateOpts{Period: 30, Digits: otp.DigitsSix, Algorithm: otp.AlgorithmSHA1})
	if err != nil {
		t.Fatal(err)
	}
	return c
}

func (e *env) call(method, path, token string, body any) (int, map[string]any, string) {
	e.t.Helper()
	var r io.Reader
	if body != nil {
		b, _ := json.Marshal(body)
		r = strings.NewReader(string(b))
	}
	req, _ := http.NewRequest(method, e.srv+path, r)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		e.t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	raw, _ := io.ReadAll(res.Body)
	var out map[string]any
	_ = json.Unmarshal(raw, &out)
	return res.StatusCode, out, string(raw)
}

func (e *env) login(totpCode string) (int, map[string]any) {
	body := map[string]any{"identity": "alice@test.local", "password": password}
	if totpCode != "" {
		body["totp"] = totpCode
	}
	status, out, _ := e.call(http.MethodPost, "/api/collections/users/auth-with-password", "", body)
	return status, out
}

// enroll runs setup + enable at step 0 and returns the secret and recovery codes.
func (e *env) enroll() (string, []string) {
	e.t.Helper()
	status, out, raw := e.call(http.MethodPost, "/api/v1/me/totp/setup", e.token, nil)
	if status != 200 || !strings.HasPrefix(out["qrCode"].(string), "data:image/png;base64,") {
		e.t.Fatalf("setup: %d %s", status, raw)
	}
	secret := out["secret"].(string)
	status, out, raw = e.call(http.MethodPost, "/api/v1/me/totp/enable", e.token, map[string]any{"code": code(e.t, secret, e.at(0))})
	if status != 200 {
		e.t.Fatalf("enable: %d %s", status, raw)
	}
	var codes []string
	for _, c := range out["recoveryCodes"].([]any) {
		codes = append(codes, c.(string))
	}
	return secret, codes
}

func TestEnrolmentAndSignIn(t *testing.T) {
	e := setup(t)
	if status, _ := e.login(""); status != 200 {
		t.Fatalf("login before 2FA: %d", status)
	}
	secret, codes := e.enroll()
	if len(codes) != 10 {
		t.Fatalf("expected 10 recovery codes, got %d", len(codes))
	}

	status, out := e.login("")
	if status != 401 || out["data"].(map[string]any)["totpRequired"] != true {
		t.Fatalf("login without code: %d %v", status, out)
	}
	if status, _ := e.login("000000"); status != 401 {
		t.Errorf("wrong code accepted: %d", status)
	}
	now := e.at(1)
	good := code(t, secret, now)
	if status, out := e.login(good); status != 200 || out["token"] == nil {
		t.Fatalf("login with code: %d %v", status, out)
	}
	if status, _ := e.login(good); status != 401 {
		t.Error("a code was accepted twice (replay)")
	}

	// Recovery codes work once, with or without dash and in any case.
	rc := strings.ToLower(strings.ReplaceAll(codes[0], "-", ""))
	if status, _ := e.login(rc); status != 200 {
		t.Errorf("recovery code login: %d", status)
	}
	if status, _ := e.login(codes[0]); status != 401 {
		t.Error("recovery code reused")
	}
	_, st, _ := e.call(http.MethodGet, "/api/v1/me/totp", e.token, nil)
	if st["enabled"] != true || st["recoveryCodesLeft"].(float64) != 9 {
		t.Errorf("status: %v", st)
	}
}

func TestWrongPasswordNeverRevealsTwoFactor(t *testing.T) {
	e := setup(t)
	e.enroll()
	status, out, raw := e.call(http.MethodPost, "/api/collections/users/auth-with-password", "",
		map[string]any{"identity": "alice@test.local", "password": "wrong"})
	if status != 400 || strings.Contains(raw, "totp") {
		t.Fatalf("wrong password response leaks 2FA: %d %v", status, out)
	}
}

func TestDisableAndRegenerateNeedPasswordAndCode(t *testing.T) {
	e := setup(t)
	secret, _ := e.enroll()

	c1 := code(t, secret, e.at(1))
	if status, _, _ := e.call(http.MethodPost, "/api/v1/me/totp/recovery-codes", e.token,
		map[string]any{"password": "wrong", "code": c1}); status != 400 {
		t.Errorf("regenerate with wrong password: %d", status)
	}
	c2 := code(t, secret, e.at(2))
	status, out, _ := e.call(http.MethodPost, "/api/v1/me/totp/recovery-codes", e.token,
		map[string]any{"password": password, "code": c2})
	if status != 200 || len(out["recoveryCodes"].([]any)) != 10 {
		t.Fatalf("regenerate: %d %v", status, out)
	}

	c3 := code(t, secret, e.at(3))
	if status, _, raw := e.call(http.MethodPost, "/api/v1/me/totp/disable", e.token,
		map[string]any{"password": password, "code": c3}); status != 204 {
		t.Fatalf("disable: %d %s", status, raw)
	}
	if status, _ := e.login(""); status != 200 {
		t.Errorf("login after disabling 2FA: %d", status)
	}
}

func TestSecretsAreEncryptedAndNotExposed(t *testing.T) {
	e := setup(t)
	secret, codes := e.enroll()
	rec, err := e.app.FindFirstRecordByData(totp.Collection, "user", e.user.Id)
	if err != nil {
		t.Fatal(err)
	}
	if enc := rec.GetString("secret_enc"); enc == "" || strings.Contains(enc, secret) {
		t.Fatalf("secret stored in clear: %q", enc)
	}
	raw, _ := json.Marshal(rec.Get("recovery"))
	if strings.Contains(string(raw), codes[1]) {
		t.Fatal("recovery codes stored in clear")
	}
	status, _, _ := e.call(http.MethodGet, "/api/collections/totp/records", e.token, nil)
	if status != 403 {
		t.Errorf("totp collection reachable through the API: %d", status)
	}
}

func TestSetupRefusedWhenAlreadyEnabled(t *testing.T) {
	e := setup(t)
	e.enroll()
	if status, _, _ := e.call(http.MethodPost, "/api/v1/me/totp/setup", e.token, nil); status != 409 {
		t.Errorf("setup while enabled: %d", status)
	}
}
