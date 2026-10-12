package maps_test

import (
	"io"
	"net/http"
	"strings"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/maps"
	"github.com/Paul-Carouge/Alcove/server/internal/security"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

func TestTilesSettingAndCSP(t *testing.T) {
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	m := maps.Register(app)
	security.RegisterHeaders(app, "script-src 'self'", m.ExtraImgSrc)
	_, userTok := testutil.User(t, app, "user@test.local")
	admin, adminTok := testutil.User(t, app, "admin@test.local")
	admin.Set("role", "admin")
	if err := app.Save(admin); err != nil {
		t.Fatal(err)
	}
	srv := testutil.Server(t, app).URL

	call := func(method, path, token, body string) (*http.Response, string) {
		req, _ := http.NewRequest(method, srv+path, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		if token != "" {
			req.Header.Set("Authorization", token)
		}
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		defer func() { _ = res.Body.Close() }()
		b, _ := io.ReadAll(res.Body)
		return res, string(b)
	}
	csp := func() string {
		res, _ := call(http.MethodGet, "/photos/map", "", "")
		return res.Header.Get("Content-Security-Policy")
	}

	if _, body := call(http.MethodGet, "/api/v1/map/config", userTok, ""); !strings.Contains(body, `"tiles":null`) {
		t.Errorf("default config = %s", body)
	}
	if strings.Contains(csp(), maps.OSMOrigin) {
		t.Error("tiles allowed by default")
	}
	if res, _ := call(http.MethodPut, "/api/v1/admin/map", userTok, `{"osm":true}`); res.StatusCode != http.StatusForbidden {
		t.Errorf("non-admin enabled tiles: %d", res.StatusCode)
	}
	if res, body := call(http.MethodPut, "/api/v1/admin/map", adminTok, `{"osm":true}`); res.StatusCode != http.StatusOK ||
		!strings.Contains(body, "tile.openstreetmap.org") {
		t.Fatalf("enable: %d %s", res.StatusCode, body)
	}
	if !strings.Contains(csp(), "img-src 'self' data: blob: "+maps.OSMOrigin) {
		t.Errorf("CSP after enabling: %s", csp())
	}
	// The setting survives a restart.
	rec, err := app.FindFirstRecordByFilter("app_settings", "key = 'map.osm'")
	if err != nil {
		t.Fatal(err)
	}
	var on bool
	_ = rec.UnmarshalJSONField("value", &on)
	if !on {
		t.Error("setting not stored")
	}
	call(http.MethodPut, "/api/v1/admin/map", adminTok, `{"osm":false}`)
	if strings.Contains(csp(), maps.OSMOrigin) {
		t.Error("tiles still allowed after disabling")
	}
}
