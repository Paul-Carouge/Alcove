package appdist_test

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync/atomic"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/appdist"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

const key = "8Zq0Y000dsFVDUjanc3Tf/pub4U3RfwuBaYeUDeaDEA="

// fakeGitHub serves the release v1.2.3 with an APK, and counts APK downloads.
func fakeGitHub(t *testing.T, withAPK bool) (*updater.Client, *atomic.Int32) {
	t.Helper()
	var downloads atomic.Int32
	var srv *httptest.Server
	srv = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/repos/o/r/releases/tags/v1.2.3":
			assets := []map[string]string{}
			if withAPK {
				assets = append(assets, map[string]string{"name": appdist.Asset, "browser_download_url": srv.URL + "/dl/apk"})
			}
			_ = json.NewEncoder(w).Encode(map[string]any{"tag_name": "v1.2.3", "assets": assets})
		case "/dl/apk":
			downloads.Add(1)
			_, _ = w.Write([]byte("PK-fake-apk"))
		default:
			http.NotFound(w, r)
		}
	}))
	t.Cleanup(srv.Close)
	c, err := updater.New(srv.URL, "o/r", key)
	if err != nil {
		t.Fatal(err)
	}
	return c, &downloads
}

func get(t *testing.T, url, token string) (int, string, http.Header) {
	t.Helper()
	req, _ := http.NewRequest(http.MethodGet, url, nil)
	if token != "" {
		req.Header.Set("Authorization", token)
	}
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	b, _ := io.ReadAll(res.Body)
	return res.StatusCode, string(b), res.Header
}

func TestAndroidAppForServerVersion(t *testing.T) {
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	client, downloads := fakeGitHub(t, true)
	appdist.Register(app, client, "1.2.3")
	user, tok := testutil.User(t, app, "u@test.local")
	srv := testutil.Server(t, app).URL

	if s, _, _ := get(t, srv+"/api/v1/app/android", ""); s != 401 {
		t.Errorf("anonymous info: %d", s)
	}
	s, body, _ := get(t, srv+"/api/v1/app/android", tok)
	if s != 200 || !strings.Contains(body, `"version":"1.2.3"`) || !strings.Contains(body, `"available":true`) {
		t.Fatalf("info: %d %s", s, body)
	}
	if s, _, _ := get(t, srv+"/api/v1/app/android.apk", ""); s != 401 {
		t.Errorf("download without a file token: %d", s)
	}
	fileTok, _ := user.NewFileToken()
	for range 2 {
		s, body, h := get(t, srv+"/api/v1/app/android.apk?token="+fileTok, "")
		if s != 200 || body != "PK-fake-apk" || h.Get("Content-Type") != "application/vnd.android.package-archive" {
			t.Fatalf("download: %d %q %s", s, body, h.Get("Content-Type"))
		}
	}
	if downloads.Load() != 1 {
		t.Errorf("APK fetched %d times from the release, want once (cached)", downloads.Load())
	}
	if _, body, _ := get(t, srv+"/api/v1/app/android", tok); !strings.Contains(body, `"size":11`) {
		t.Errorf("info after caching: %s", body)
	}
}

func TestNoAppToOffer(t *testing.T) {
	for name, c := range map[string]struct {
		version string
		withAPK bool
	}{
		"development build":   {"1.2.3-4-gabc", true},
		"release without APK": {"1.2.3", false},
	} {
		t.Run(name, func(t *testing.T) {
			app := testutil.NewApp(t)
			t.Cleanup(app.Cleanup)
			client, _ := fakeGitHub(t, c.withAPK)
			appdist.Register(app, client, c.version)
			user, tok := testutil.User(t, app, "u@test.local")
			srv := testutil.Server(t, app).URL
			if _, body, _ := get(t, srv+"/api/v1/app/android", tok); !strings.Contains(body, `"available":false`) {
				t.Errorf("info: %s", body)
			}
			fileTok, _ := user.NewFileToken()
			if s, _, _ := get(t, srv+"/api/v1/app/android.apk?token="+fileTok, ""); s != 404 {
				t.Errorf("download: %d", s)
			}
		})
	}
}
