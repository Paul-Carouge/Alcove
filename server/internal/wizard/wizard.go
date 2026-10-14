// Package wizard implements the first-run setup wizard (see the "setup" tag
// in the OpenAPI spec). It only works while no administrator exists, with a
// one-time token printed in the logs or preset with ALCOVE_SETUP_TOKEN.
package wizard

import (
	"cmp"
	"crypto/rand"
	"crypto/subtle"
	"encoding/base64"
	"errors"
	"fmt"
	"net/http"
	"net/mail"
	"strings"
	"sync"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/mailer"
	"github.com/pocketbase/pocketbase/tools/security"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/netaddr"
)

// MinPasswordLength matches the web client's rule.
const MinPasswordLength = 10

type wizard struct {
	mu    sync.Mutex
	token string // empty once setup is complete
}

// Register mounts the routes and replaces PocketBase's installer link with
// the wizard link.
func Register(app core.App, cfg config.Config) {
	w := &wizard{token: cfg.SetupToken}
	if w.token == "" {
		w.token = randomToken()
	}

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		if se.InstallerFunc != nil {
			// Called only while no administrator exists. Never opens a browser.
			se.InstallerFunc = func(app core.App, _ *core.Record, listenURL string) error {
				w.printLink(app, cmp.Or(cfg.PublicURL, listenURL), cfg.SetupToken != "")
				return nil
			}
		}
		se.Router.POST("/api/v1/setup/status", w.status)
		se.Router.POST("/api/v1/setup/smtp-test", w.smtpTest)
		se.Router.POST("/api/v1/setup", w.complete)
		return se.Next()
	})
}

func randomToken() string {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		panic(err) // crypto/rand never fails on supported platforms
	}
	return base64.RawURLEncoding.EncodeToString(b)
}

func (w *wizard) printLink(app core.App, baseURL string, preset bool) {
	// "http://0.0.0.0:8090" cannot be opened: show the machine's network addresses instead.
	var links []string
	for _, b := range netaddr.Reachable(baseURL) {
		link := strings.TrimRight(b, "/") + "/setup"
		if !preset {
			link += "?token=" + w.token
		}
		links = append(links, link)
	}
	app.Logger().Info("first launch: open the setup wizard", "url", links[0])
	fmt.Printf("\n(!) First launch: finish setting up %s at\n%s\n", buildinfo.Name, strings.Join(links, "\n"))
	if preset {
		fmt.Println("    (use the token from ALCOVE_SETUP_TOKEN)")
	}
	fmt.Println()
}

// Required reports whether no real administrator exists yet (PocketBase
// keeps a placeholder installer account until then).
func Required(app core.App) bool {
	n, err := app.CountRecords(core.CollectionNameSuperusers,
		dbx.Not(dbx.HashExp{"email": core.DefaultInstallerEmail}))
	return err == nil && n == 0
}

// guard checks the state and the token; it writes the error response itself.
func (w *wizard) guard(e *core.RequestEvent, token string) error {
	if !Required(e.App) {
		return e.Error(http.StatusConflict, "Setup is already complete.", nil)
	}
	w.mu.Lock()
	expected := w.token
	w.mu.Unlock()
	if expected == "" || subtle.ConstantTimeCompare([]byte(expected), []byte(token)) != 1 {
		return e.ForbiddenError("Invalid setup token.", nil)
	}
	return nil
}

func (w *wizard) status(e *core.RequestEvent) error {
	var body struct {
		Token string `json:"token"`
	}
	_ = e.BindBody(&body)
	if err := w.guard(e, body.Token); err != nil {
		return err
	}
	storage := map[string]any{"type": "local", "writable": true}
	if e.App.Settings().S3.Enabled {
		storage["type"] = "s3"
	}
	if err := checkStorage(e.App); err != nil {
		storage["writable"] = false
		storage["error"] = err.Error()
	}
	return e.JSON(http.StatusOK, map[string]any{"storage": storage})
}

// checkStorage writes, reads back and deletes a small file.
func checkStorage(app core.App) error {
	fsys, err := app.NewFilesystem()
	if err != nil {
		return err
	}
	defer func() { _ = fsys.Close() }()
	key := "_alcove_setup_check/" + security.RandomString(16) + ".txt"
	if err := fsys.Upload([]byte("ok"), key); err != nil {
		return fmt.Errorf("write failed: %w", err)
	}
	ok, err := fsys.Exists(key)
	if err != nil {
		return fmt.Errorf("read back failed: %w", err)
	}
	if !ok {
		return errors.New("written file not found")
	}
	if err := fsys.Delete(key); err != nil {
		return fmt.Errorf("delete failed: %w", err)
	}
	return nil
}

type smtpSettings struct {
	Host          string `json:"host"`
	Port          int    `json:"port"`
	Username      string `json:"username"`
	Password      string `json:"password"`
	TLS           bool   `json:"tls"`
	SenderAddress string `json:"senderAddress"`
	SenderName    string `json:"senderName"`
}

func (s *smtpSettings) valid() bool {
	_, err := mail.ParseAddress(s.SenderAddress)
	return s.Host != "" && len(s.Host) <= 253 && s.Port > 0 && s.Port <= 65535 && err == nil
}

func (w *wizard) smtpTest(e *core.RequestEvent) error {
	var body struct {
		Token string       `json:"token"`
		SMTP  smtpSettings `json:"smtp"`
		To    string       `json:"to"`
	}
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("Invalid body.", nil)
	}
	if err := w.guard(e, body.Token); err != nil {
		return err
	}
	to, err := mail.ParseAddress(body.To)
	if err != nil || !body.SMTP.valid() {
		return e.BadRequestError("Invalid SMTP settings or recipient.", nil)
	}
	client := &mailer.SMTPClient{
		Host: body.SMTP.Host, Port: body.SMTP.Port, Username: body.SMTP.Username,
		Password: body.SMTP.Password, TLS: body.SMTP.TLS,
	}
	err = client.Send(&mailer.Message{
		From:    mail.Address{Name: cmp.Or(body.SMTP.SenderName, buildinfo.Name), Address: body.SMTP.SenderAddress},
		To:      []mail.Address{*to},
		Subject: buildinfo.Name + ": test email",
		Text:    "Your " + buildinfo.Name + " server can send email.",
		HTML:    "<p>Your " + buildinfo.Name + " server can send email.</p>",
	})
	if err != nil {
		return e.BadRequestError("The SMTP server rejected the message: "+err.Error(), nil)
	}
	return e.NoContent(http.StatusNoContent)
}

func (w *wizard) complete(e *core.RequestEvent) error {
	var body struct {
		Token string `json:"token"`
		Admin struct {
			Name     string `json:"name"`
			Email    string `json:"email"`
			Password string `json:"password"`
		} `json:"admin"`
		SMTP *smtpSettings `json:"smtp"`
	}
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("Invalid body.", nil)
	}
	// Serialize completion: two concurrent requests must not both succeed.
	w.mu.Lock()
	defer w.mu.Unlock()
	if !Required(e.App) {
		return e.Error(http.StatusConflict, "Setup is already complete.", nil)
	}
	if w.token == "" || subtle.ConstantTimeCompare([]byte(w.token), []byte(body.Token)) != 1 {
		return e.ForbiddenError("Invalid setup token.", nil)
	}

	addr, err := mail.ParseAddress(body.Admin.Email)
	if err != nil || addr.Address != strings.TrimSpace(body.Admin.Email) {
		return e.BadRequestError("Invalid email address.", nil)
	}
	if n := len(body.Admin.Password); n < MinPasswordLength || n > 256 {
		return e.BadRequestError(fmt.Sprintf("The password must be %d to 256 characters long.", MinPasswordLength), nil)
	}
	if body.SMTP != nil && !body.SMTP.valid() {
		return e.BadRequestError("Invalid SMTP settings.", nil)
	}

	err = e.App.RunInTransaction(func(tx core.App) error {
		supers, err := tx.FindCollectionByNameOrId(core.CollectionNameSuperusers)
		if err != nil {
			return err
		}
		admin := core.NewRecord(supers)
		admin.SetEmail(addr.Address)
		admin.SetPassword(body.Admin.Password)
		if err := tx.Save(admin); err != nil {
			return err
		}

		// The same person also gets an app account (superusers cannot use the app).
		users, err := tx.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		user := core.NewRecord(users)
		user.SetEmail(addr.Address)
		user.SetPassword(body.Admin.Password)
		user.SetVerified(true)
		user.Set("name", strings.TrimSpace(body.Admin.Name))
		user.Set("role", "admin")
		if err := tx.Save(user); err != nil {
			return err
		}

		if placeholder, err := tx.FindAuthRecordByEmail(supers, core.DefaultInstallerEmail); err == nil {
			if err := tx.Delete(placeholder); err != nil {
				return err
			}
		}

		if body.SMTP != nil {
			s := tx.Settings()
			s.SMTP.Enabled = true
			s.SMTP.Host, s.SMTP.Port = body.SMTP.Host, body.SMTP.Port
			s.SMTP.Username, s.SMTP.Password, s.SMTP.TLS = body.SMTP.Username, body.SMTP.Password, body.SMTP.TLS
			s.Meta.SenderAddress = body.SMTP.SenderAddress
			s.Meta.SenderName = cmp.Or(body.SMTP.SenderName, buildinfo.Name)
			if err := tx.Save(s); err != nil {
				return err
			}
		}
		return nil
	})
	if err != nil {
		return e.BadRequestError("Could not create the administrator.", err)
	}
	w.token = "" // one-time
	e.App.Logger().Info("setup complete", "admin", addr.Address)
	return e.NoContent(http.StatusNoContent)
}
