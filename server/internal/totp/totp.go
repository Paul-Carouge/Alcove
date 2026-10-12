// Package totp adds authenticator-app two-factor authentication (RFC 6238)
// to the users collection. See the "account" tag in the OpenAPI spec.
package totp

import (
	"bytes"
	"crypto/rand"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base32"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"image/png"
	"net/http"
	"regexp"
	"slices"
	"strings"
	"time"

	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pquerna/otp"
	"github.com/pquerna/otp/totp"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/secrets"
)

const (
	Collection    = "totp"
	period        = 30
	recoveryCount = 10
	// skew accepts the previous and next 30 s window (clock drift).
	skew = 1
)

var (
	sixDigits = regexp.MustCompile(`^[0-9]{6}$`)
	opts      = totp.ValidateOpts{Period: period, Digits: otp.DigitsSix, Algorithm: otp.AlgorithmSHA1}
)

// clock is replaced in tests.
var clock = time.Now

type service struct {
	keys *secrets.Keyring
}

// Register mounts the account routes and the sign-in checks.
func Register(app core.App, keys *secrets.Keyring) {
	s := &service{keys: keys}

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		g := se.Router.Group("/api/v1/me/totp").Bind(apis.RequireAuth("users"))
		g.GET("", s.status)
		g.POST("/setup", s.setup)
		g.POST("/enable", s.enable)
		g.POST("/disable", s.disable)
		g.POST("/recovery-codes", s.regenerate)
		return se.Next()
	})

	app.OnRecordAuthWithPasswordRequest("users").BindFunc(s.onPasswordAuth)
	app.OnRecordAuthWithOTPRequest("users").BindFunc(s.onOTPAuth)
}

// --- storage ---

func enrolment(app core.App, userID string) (*core.Record, error) {
	return app.FindFirstRecordByData(Collection, "user", userID)
}

// Enabled reports whether the account uses an authenticator app.
func Enabled(app core.App, userID string) bool {
	_, on := enabledFor(app, userID)
	return on
}

func enabledFor(app core.App, userID string) (*core.Record, bool) {
	rec, err := enrolment(app, userID)
	return rec, err == nil && rec.GetBool("enabled")
}

func recoveryHashes(rec *core.Record) []string {
	var hashes []string
	_ = rec.UnmarshalJSONField("recovery", &hashes)
	return hashes
}

func hashRecovery(code string) string {
	sum := sha256.Sum256([]byte(normalizeRecovery(code)))
	return hex.EncodeToString(sum[:])
}

func normalizeRecovery(code string) string {
	return strings.ToUpper(strings.NewReplacer("-", "", " ", "").Replace(strings.TrimSpace(code)))
}

// newRecoveryCodes returns display codes (XXXXX-XXXXX, 50 bits each) and their hashes.
func newRecoveryCodes() (codes, hashes []string, err error) {
	enc := base32.StdEncoding.WithPadding(base32.NoPadding)
	for range recoveryCount {
		b := make([]byte, 7)
		if _, err := rand.Read(b); err != nil {
			return nil, nil, err
		}
		raw := enc.EncodeToString(b)[:10]
		code := raw[:5] + "-" + raw[5:]
		codes = append(codes, code)
		hashes = append(hashes, hashRecovery(code))
	}
	return codes, hashes, nil
}

// verify checks a 6-digit code (never twice for the same time step) or a
// recovery code (single use). It persists the consumed step/code.
func (s *service) verify(app core.App, rec *core.Record, code string) bool {
	code = strings.TrimSpace(code)
	if sixDigits.MatchString(code) {
		secret, err := s.keys.Decrypt(rec.GetString("secret_enc"))
		if err != nil {
			app.Logger().Error("cannot decrypt TOTP secret", "error", err)
			return false
		}
		current := clock().Unix() / period
		last := int64(rec.GetInt("last_step"))
		for step := current - skew; step <= current+skew; step++ {
			if step <= last {
				continue // replay protection
			}
			want, err := totp.GenerateCodeCustom(secret, time.Unix(step*period, 0), opts)
			if err == nil && subtle.ConstantTimeCompare([]byte(want), []byte(code)) == 1 {
				rec.Set("last_step", step)
				return app.Save(rec) == nil
			}
		}
		return false
	}
	if len(normalizeRecovery(code)) != 10 {
		return false
	}
	hashes := recoveryHashes(rec)
	h := hashRecovery(code)
	i := slices.Index(hashes, h)
	if i < 0 {
		return false
	}
	rec.Set("recovery", slices.Delete(hashes, i, i+1))
	return app.Save(rec) == nil
}

// --- account routes ---

func (s *service) status(e *core.RequestEvent) error {
	rec, on := enabledFor(e.App, e.Auth.Id)
	left := 0
	if on {
		left = len(recoveryHashes(rec))
	}
	return e.JSON(http.StatusOK, map[string]any{"enabled": on, "recoveryCodesLeft": left})
}

func (s *service) setup(e *core.RequestEvent) error {
	if _, on := enabledFor(e.App, e.Auth.Id); on {
		return e.Error(http.StatusConflict, "Two-factor is already enabled.", nil)
	}
	key, err := totp.Generate(totp.GenerateOpts{
		Issuer: buildinfo.Name, AccountName: e.Auth.Email(), Period: period, Digits: otp.DigitsSix, Algorithm: otp.AlgorithmSHA1,
	})
	if err != nil {
		return err
	}
	enc, err := s.keys.Encrypt(key.Secret())
	if err != nil {
		return err
	}
	rec, err := enrolment(e.App, e.Auth.Id)
	if err != nil {
		col, err := e.App.FindCollectionByNameOrId(Collection)
		if err != nil {
			return err
		}
		rec = core.NewRecord(col)
		rec.Set("user", e.Auth.Id)
	}
	rec.Set("secret_enc", enc)
	rec.Set("enabled", false)
	rec.Set("recovery", []string{})
	rec.Set("last_step", 0)
	if err := e.App.Save(rec); err != nil {
		return err
	}

	img, err := key.Image(256, 256)
	if err != nil {
		return err
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return err
	}
	return e.JSON(http.StatusOK, map[string]any{
		"secret":     key.Secret(),
		"otpauthUrl": key.URL(),
		"qrCode":     "data:image/png;base64," + base64.StdEncoding.EncodeToString(buf.Bytes()),
	})
}

func (s *service) enable(e *core.RequestEvent) error {
	var body struct {
		Code string `json:"code"`
	}
	if err := e.BindBody(&body); err != nil || !sixDigits.MatchString(body.Code) {
		return e.BadRequestError("A 6-digit code is required.", nil)
	}
	rec, err := enrolment(e.App, e.Auth.Id)
	if err != nil || rec.GetBool("enabled") {
		return e.BadRequestError("No pending enrolment.", nil)
	}
	if !s.verify(e.App, rec, body.Code) {
		return e.BadRequestError("Invalid code.", nil)
	}
	codes, hashes, err := newRecoveryCodes()
	if err != nil {
		return err
	}
	rec.Set("enabled", true)
	rec.Set("recovery", hashes)
	if err := e.App.Save(rec); err != nil {
		return err
	}
	return e.JSON(http.StatusOK, map[string]any{"recoveryCodes": codes})
}

// confirm re-checks the password and a second factor before sensitive changes.
func (s *service) confirm(e *core.RequestEvent) (*core.Record, error) {
	var body struct {
		Password string `json:"password"`
		Code     string `json:"code"`
	}
	if err := e.BindBody(&body); err != nil || body.Password == "" || body.Code == "" {
		return nil, e.BadRequestError("Password and code are required.", nil)
	}
	rec, on := enabledFor(e.App, e.Auth.Id)
	if !on {
		return nil, e.BadRequestError("Two-factor is not enabled.", nil)
	}
	if !e.Auth.ValidatePassword(body.Password) || !s.verify(e.App, rec, body.Code) {
		return nil, e.BadRequestError("Wrong password or code.", nil)
	}
	return rec, nil
}

func (s *service) disable(e *core.RequestEvent) error {
	rec, err := s.confirm(e)
	if err != nil {
		return err
	}
	if err := e.App.Delete(rec); err != nil {
		return err
	}
	return e.NoContent(http.StatusNoContent)
}

func (s *service) regenerate(e *core.RequestEvent) error {
	rec, err := s.confirm(e)
	if err != nil {
		return err
	}
	codes, hashes, err := newRecoveryCodes()
	if err != nil {
		return err
	}
	rec.Set("recovery", hashes)
	if err := e.App.Save(rec); err != nil {
		return err
	}
	return e.JSON(http.StatusOK, map[string]any{"recoveryCodes": codes})
}

// --- sign-in ---

var errTOTP = errors.New("totp required")

// totpChallenge answers 401 with data.totpRequired (written directly:
// PocketBase rewrites ApiError data into validation errors).
func totpChallenge(e *core.RequestEvent, invalid bool) error {
	msg := "Enter the code from your authenticator app."
	if invalid {
		msg = "Invalid two-factor code."
	}
	return e.JSON(http.StatusUnauthorized, map[string]any{
		"status": http.StatusUnauthorized, "message": msg,
		"data": map[string]any{"totpRequired": true, "invalid": invalid},
	})
}

func bodyString(e *core.RequestEvent, key string) string {
	info, err := e.RequestInfo()
	if err != nil {
		return ""
	}
	v, _ := info.Body[key].(string)
	return v
}

// onPasswordAuth runs before PocketBase checks the password, so it checks the
// password first: the second factor is only requested from someone who
// already knows it (otherwise 2FA status would leak).
func (s *service) onPasswordAuth(e *core.RecordAuthWithPasswordRequestEvent) error {
	if e.Record == nil || !e.Record.ValidatePassword(e.Password) {
		return e.Next() // PocketBase answers with its generic failure
	}
	rec, on := enabledFor(e.App, e.Record.Id)
	if !on {
		return e.Next()
	}
	code := bodyString(e.RequestEvent, "totp")
	if code == "" {
		return totpChallenge(e.RequestEvent, false)
	}
	if !s.verify(e.App, rec, code) {
		return totpChallenge(e.RequestEvent, true)
	}
	return e.Next()
}

// onOTPAuth stops email codes from bypassing TOTP. The second step of an MFA
// flow (mfaId present) is allowed: the password step already required TOTP.
func (s *service) onOTPAuth(e *core.RecordAuthWithOTPRequestEvent) error {
	if e.Record == nil || bodyString(e.RequestEvent, "mfaId") != "" {
		return e.Next()
	}
	rec, on := enabledFor(e.App, e.Record.Id)
	if !on {
		return e.Next()
	}
	if code := bodyString(e.RequestEvent, "totp"); code == "" || !s.verify(e.App, rec, code) {
		return e.BadRequestError("Failed to authenticate.", errTOTP)
	}
	return e.Next()
}
