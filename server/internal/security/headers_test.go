package security_test

import (
	"net/http"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	"github.com/Paul-Carouge/Alcove/server/internal/security"
)

func TestHeaders(t *testing.T) {
	const scriptSrc = "script-src 'self' 'sha256-test='"
	factory := func(tb testing.TB) *tests.TestApp {
		app, err := tests.NewTestApp()
		if err != nil {
			tb.Fatal(err)
		}
		security.RegisterHeaders(app, scriptSrc)
		app.OnServe().BindFunc(func(se *core.ServeEvent) error {
			se.Router.GET("/page", func(e *core.RequestEvent) error { return e.String(http.StatusOK, "ok") })
			return se.Next()
		})
		return app
	}

	scenario := tests.ApiScenario{
		Name:            "web UI routes get the full CSP including script hashes",
		Method:          http.MethodGet,
		URL:             "/page",
		TestAppFactory:  factory,
		ExpectedStatus:  http.StatusOK,
		ExpectedContent: []string{"ok"},
		AfterTestFunc: func(t testing.TB, _ *tests.TestApp, res *http.Response) {
			want := security.ContentSecurityPolicy(scriptSrc)
			if got := res.Header.Get("Content-Security-Policy"); got != want {
				t.Errorf("CSP = %q, want %q", got, want)
			}
			if res.Header.Get("X-Content-Type-Options") != "nosniff" {
				t.Error("missing nosniff")
			}
		},
	}
	scenario.Test(t)
}
