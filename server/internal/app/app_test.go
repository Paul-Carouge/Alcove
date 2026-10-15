package app_test

import (
	"net/http"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/app"
	"github.com/Paul-Carouge/Alcove/server/internal/config"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

// Building the router with every module catches route conflicts (which
// panic at startup) and checks key routes are reachable together.
func TestFullWiringServes(t *testing.T) {
	a := testutil.NewApp(t)
	t.Cleanup(a.Cleanup)
	app.Wire(a, config.Config{})
	srv := testutil.Server(t, a)

	for path, want := range map[string]int{
		"/health":                         http.StatusOK,
		"/":                               http.StatusOK,       // SPA (or the "not built" placeholder)
		"/api/v1/uploads/":                http.StatusNotFound, // no GET on the tus endpoint
		"/api/nope":                       http.StatusNotFound,
		"/api/collections/nodes/records":  http.StatusOK,
		"/api/collections/notes/records":  http.StatusOK,
		"/api/collections/events/records": http.StatusOK,
	} {
		res, err := http.Get(srv.URL + path)
		if err != nil {
			t.Fatal(err)
		}
		_ = res.Body.Close()
		if res.StatusCode != want {
			t.Errorf("GET %s = %d, want %d", path, res.StatusCode, want)
		}
	}
}
