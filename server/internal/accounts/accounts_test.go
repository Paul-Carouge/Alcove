package accounts_test

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/accounts"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

func TestAccounts(t *testing.T) {
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	accounts.Register(app)
	admin, adminTok := testutil.User(t, app, "admin@test.local")
	admin.Set("role", "admin")
	if err := app.Save(admin); err != nil {
		t.Fatal(err)
	}
	_, userTok := testutil.User(t, app, "user@test.local")
	srv := testutil.Server(t, app).URL

	call := func(method, path, token, body string) (int, map[string]any) {
		req, _ := http.NewRequest(method, srv+path, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		req.Header.Set("Authorization", token)
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer func() { _ = res.Body.Close() }()
		b, _ := io.ReadAll(res.Body)
		var out map[string]any
		_ = json.Unmarshal(b, &out)
		return res.StatusCode, out
	}

	if s, _ := call("GET", "/api/v1/admin/users", userTok, ""); s != 403 {
		t.Errorf("regular user listed accounts: %d", s)
	}
	s, out := call("POST", "/api/v1/admin/users", adminTok,
		`{"email":"kid@test.local","name":" Kid ","password":"kid-password-123","quotaBytes":1000}`)
	if s != 201 || out["name"] != "Kid" || out["quotaBytes"].(float64) != 1000 || out["admin"] != false {
		t.Fatalf("create: %d %v", s, out)
	}
	kidID := out["id"].(string)
	if s, out := call("POST", "/api/v1/admin/users", adminTok,
		`{"email":"KID@test.local","password":"kid-password-123"}`); s != 400 || !strings.Contains(out["message"].(string), "already used") {
		t.Errorf("duplicate email: %d %v", s, out)
	}
	if s, _ := call("POST", "/api/v1/admin/users", adminTok, `{"email":"x@test.local","password":"short"}`); s != 400 {
		t.Errorf("short password accepted: %d", s)
	}

	// The new account can sign in; usage counts its files.
	kid, _ := app.FindRecordById("users", kidID)
	if !kid.Verified() || !kid.ValidatePassword("kid-password-123") {
		t.Fatal("account not ready to sign in")
	}
	n := testutil.Node(t, app, kid, "", "a.txt", drive.KindFile)
	f, _ := filesystem.NewFileFromBytes([]byte("hello"), "a.txt")
	n.Set("blob", f)
	if err := app.Save(n); err != nil {
		t.Fatal(err)
	}
	_, listOut := call("GET", "/api/v1/admin/users", adminTok, "")
	var found map[string]any
	for _, it := range listOut["items"].([]any) {
		if it.(map[string]any)["id"] == kidID {
			found = it.(map[string]any)
		}
	}
	if found == nil || found["usedBytes"].(float64) != 5 {
		t.Errorf("listed kid = %v", found)
	}

	// A new password signs the account out everywhere.
	kidTok, _ := kid.NewAuthToken()
	if s, _ := call("PATCH", "/api/v1/admin/users/"+kidID, adminTok, `{"password":"new-password-456","quotaBytes":0,"admin":true}`); s != 200 {
		t.Fatalf("update: %d", s)
	}
	if _, err := app.FindAuthRecordByToken(kidTok, core.TokenTypeAuth); err == nil {
		t.Error("old token still valid after a password reset")
	}
	kid, _ = app.FindRecordById("users", kidID)
	if !kid.ValidatePassword("new-password-456") || kid.GetString("role") != "admin" || kid.GetInt("quota_bytes") != 0 {
		t.Error("changes not saved")
	}

	// Guards: not yourself, never the last administrator.
	if s, _ := call("PATCH", "/api/v1/admin/users/"+admin.Id, adminTok, `{"admin":false}`); s != 400 {
		t.Errorf("admin demoted themselves: %d", s)
	}
	if s, _ := call("DELETE", "/api/v1/admin/users/"+admin.Id, adminTok, ""); s != 400 {
		t.Errorf("admin deleted themselves: %d", s)
	}
	if s, _ := call("PATCH", "/api/v1/admin/users/"+kidID, adminTok, `{"admin":false}`); s != 200 {
		t.Errorf("demote a second admin: %d", s)
	}

	// Deleting removes the account and its files.
	if s, _ := call("DELETE", "/api/v1/admin/users/"+kidID, adminTok, ""); s != 204 {
		t.Fatalf("delete: %d", s)
	}
	if _, err := app.FindRecordById(drive.Collection, n.Id); err == nil {
		t.Error("files survived their account")
	}
}
