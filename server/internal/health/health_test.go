package health_test

import (
	"net/http"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	"github.com/Paul-Carouge/Alcove/server/internal/health"
)

func TestHealth(t *testing.T) {
	factory := func(modules ...string) func(testing.TB) *tests.TestApp {
		return func(tb testing.TB) *tests.TestApp {
			app, err := tests.NewTestApp()
			if err != nil {
				tb.Fatal(err)
			}
			health.Register(app, modules)
			return app
		}
	}

	scenarios := []tests.ApiScenario{
		{
			Name:           "reports version, api range and modules",
			Method:         http.MethodGet,
			URL:            health.Path,
			TestAppFactory: factory("ocr"),
			ExpectedStatus: http.StatusOK,
			ExpectedContent: []string{
				`"status":"ok"`,
				`"api":{"min":1,"max":1}`,
				`"modules":["core","ocr"]`,
				`"setupRequired":false`,
			},
		},
		{
			Name:   "setupRequired is true without superusers",
			Method: http.MethodGet,
			URL:    health.Path,
			TestAppFactory: func(tb testing.TB) *tests.TestApp {
				app := factory()(tb)
				if _, err := app.DB().NewQuery("DELETE FROM " + core.CollectionNameSuperusers).Execute(); err != nil {
					tb.Fatal(err)
				}
				return app
			},
			ExpectedStatus:  http.StatusOK,
			ExpectedContent: []string{`"modules":["core"]`, `"setupRequired":true`},
		},
	}
	for _, s := range scenarios {
		s.Test(t)
	}
}
