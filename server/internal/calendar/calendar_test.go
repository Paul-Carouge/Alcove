package calendar_test

import (
	"net/http"
	"net/url"
	"strings"
	"testing"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"

	"github.com/Paul-Carouge/Alcove/server/internal/calendar"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

const (
	eventsURL    = "/api/collections/events/records"
	calendarsURL = "/api/collections/calendars/records"
)

type fixture struct {
	app                  *tests.TestApp
	alice, bob           *core.Record
	aliceToken, bobToken string
	aliceCal, bobCal     string
	aliceEvent           *core.Record
}

func save(tb testing.TB, app core.App, collection string, fields map[string]any) *core.Record {
	tb.Helper()
	col, err := app.FindCollectionByNameOrId(collection)
	if err != nil {
		tb.Fatal(err)
	}
	r := core.NewRecord(col)
	r.Load(fields)
	if err := app.Save(r); err != nil {
		tb.Fatal(err)
	}
	return r
}

func newFixture(tb testing.TB) *fixture {
	app := testutil.NewApp(tb)
	calendar.Register(app)
	f := &fixture{app: app}
	f.alice, f.aliceToken = testutil.User(tb, app, "alice@test.local")
	f.bob, f.bobToken = testutil.User(tb, app, "bob@test.local")
	f.aliceCal = save(tb, app, "calendars", map[string]any{"owner": f.alice.Id, "name": "Personal", "color": "green", "is_default": true}).Id
	f.bobCal = save(tb, app, "calendars", map[string]any{"owner": f.bob.Id, "name": "Work", "color": "blue"}).Id
	f.aliceEvent = save(tb, app, "events", map[string]any{
		"owner": f.alice.Id, "calendar": f.aliceCal, "title": "Dentist",
		"start": "2026-10-20 09:00:00.000Z", "end": "2026-10-20 10:00:00.000Z",
	})
	return f
}

func run(t *testing.T, build func(f *fixture) tests.ApiScenario) {
	t.Helper()
	f := newFixture(t)
	s := build(f)
	s.TestAppFactory = func(testing.TB) *tests.TestApp { return f.app }
	s.Test(t)
}

func auth(token string) map[string]string { return map[string]string{"Authorization": token} }

func body(s string) *strings.Reader { return strings.NewReader(s) }

func event(owner, cal, extra string) *strings.Reader {
	return body(`{"owner":"` + owner + `","calendar":"` + cal + `","title":"Lunch",` +
		`"start":"2026-10-21 12:00:00.000Z","end":"2026-10-21 13:00:00.000Z"` + extra + `}`)
}

func TestEventsAreOwnerOnly(t *testing.T) {
	scenarios := []func(f *fixture) tests.ApiScenario{
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "guests see nothing", Method: http.MethodGet, URL: eventsURL,
				ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":0`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "the owner lists her events", Method: http.MethodGet, URL: eventsURL,
				Headers: auth(f.aliceToken), ExpectedStatus: 200,
				ExpectedContent: []string{`"totalItems":1`, `"title":"Dentist"`, `@alcove"`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "and filters them by range", Method: http.MethodGet,
				URL:     eventsURL + "?filter=" + url.QueryEscape(`start < "2026-10-21 00:00:00.000Z" && end > "2026-10-20 00:00:00.000Z"`),
				Headers: auth(f.aliceToken), ExpectedStatus: 200, ExpectedContent: []string{`"totalItems":1`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "another user does not see them", Method: http.MethodGet, URL: eventsURL,
				Headers: auth(f.bobToken), ExpectedStatus: 200,
				ExpectedContent: []string{`"totalItems":0`}, NotExpectedContent: []string{"Dentist"},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor her calendars", Method: http.MethodGet, URL: calendarsURL,
				Headers: auth(f.bobToken), ExpectedStatus: 200,
				ExpectedContent: []string{`"totalItems":1`, `"name":"Work"`}, NotExpectedContent: []string{"Personal"},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor opens one", Method: http.MethodGet, URL: eventsURL + "/" + f.aliceEvent.Id,
				Headers: auth(f.bobToken), ExpectedStatus: 404, ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor edits one", Method: http.MethodPatch, URL: eventsURL + "/" + f.aliceEvent.Id,
				Body: body(`{"title":"hacked"}`), Headers: auth(f.bobToken), ExpectedStatus: 404,
				ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor deletes one", Method: http.MethodDelete, URL: eventsURL + "/" + f.aliceEvent.Id,
				Headers: auth(f.bobToken), ExpectedStatus: 404, ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor creates one for her", Method: http.MethodPost, URL: eventsURL,
				Body: event(f.alice.Id, f.aliceCal, ""), Headers: auth(f.bobToken),
				ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor puts his event in her calendar", Method: http.MethodPost, URL: eventsURL,
				Body: event(f.bob.Id, f.aliceCal, ""), Headers: auth(f.bobToken),
				ExpectedStatus: 400, ExpectedContent: []string{`validation_calendar_owner`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor moves her event into his calendar", Method: http.MethodPatch, URL: eventsURL + "/" + f.aliceEvent.Id,
				Body: body(`{"calendar":"` + f.bobCal + `"}`), Headers: auth(f.aliceToken),
				ExpectedStatus: 400, ExpectedContent: []string{`validation_calendar_owner`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor edits her calendar", Method: http.MethodPatch, URL: calendarsURL + "/" + f.aliceCal,
				Body: body(`{"name":"mine"}`), Headers: auth(f.bobToken), ExpectedStatus: 404,
				ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "the owner cannot give an event away", Method: http.MethodPatch, URL: eventsURL + "/" + f.aliceEvent.Id,
				Body: body(`{"owner":"` + f.bob.Id + `"}`), Headers: auth(f.aliceToken), ExpectedStatus: 404,
				ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor a calendar", Method: http.MethodPatch, URL: calendarsURL + "/" + f.aliceCal,
				Body: body(`{"owner":"` + f.bob.Id + `"}`), Headers: auth(f.aliceToken), ExpectedStatus: 404,
				ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "nor change the uid", Method: http.MethodPatch, URL: eventsURL + "/" + f.aliceEvent.Id,
				Body: body(`{"uid":"other"}`), Headers: auth(f.aliceToken), ExpectedStatus: 404,
				ExpectedContent: []string{`"data":{}`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "two calendars cannot share a name", Method: http.MethodPost, URL: calendarsURL,
				Body:    body(`{"owner":"` + f.alice.Id + `","name":"personal","color":"red"}`),
				Headers: auth(f.aliceToken), ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "colors come from the tag palette", Method: http.MethodPost, URL: calendarsURL,
				Body:    body(`{"owner":"` + f.alice.Id + `","name":"Sport","color":"#ff0000"}`),
				Headers: auth(f.aliceToken), ExpectedStatus: 400, ExpectedContent: []string{`"color"`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "the owner creates a recurring event", Method: http.MethodPost, URL: eventsURL,
				Body: event(f.alice.Id, f.aliceCal, `,"rrule":"FREQ=WEEKLY;COUNT=10","location":"Café"`), Headers: auth(f.aliceToken),
				ExpectedStatus: 200, ExpectedContent: []string{`"title":"Lunch"`, `"rrule":"FREQ=WEEKLY;COUNT=10"`, `@alcove"`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "and keeps a uid it brings (a later CalDAV import)", Method: http.MethodPost, URL: eventsURL,
				Body: event(f.alice.Id, f.aliceCal, `,"uid":"abc@example.com"`), Headers: auth(f.aliceToken),
				ExpectedStatus: 200, ExpectedContent: []string{`"uid":"abc@example.com"`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "an unsupported rule is refused", Method: http.MethodPost, URL: eventsURL,
				Body: event(f.alice.Id, f.aliceCal, `,"rrule":"FREQ=WEEKLY;BYDAY=MO,WE"`), Headers: auth(f.aliceToken),
				ExpectedStatus: 400, ExpectedContent: []string{`"rrule"`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "an event cannot end before it starts", Method: http.MethodPatch, URL: eventsURL + "/" + f.aliceEvent.Id,
				Body: body(`{"end":"2026-10-20 08:00:00.000Z"}`), Headers: auth(f.aliceToken),
				ExpectedStatus: 400, ExpectedContent: []string{`validation_end_before_start`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "all-day events cover whole dates", Method: http.MethodPost, URL: eventsURL,
				Body: event(f.alice.Id, f.aliceCal, `,"all_day":true`), Headers: auth(f.aliceToken),
				ExpectedStatus: 400, ExpectedContent: []string{`validation_all_day_time`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "an all-day event on two days", Method: http.MethodPost, URL: eventsURL,
				Body: body(`{"owner":"` + f.alice.Id + `","calendar":"` + f.aliceCal + `","title":"Trip","all_day":true,` +
					`"start":"2026-10-24 00:00:00.000Z","end":"2026-10-26 00:00:00.000Z","rrule":"FREQ=YEARLY;UNTIL=20300101"}`),
				Headers: auth(f.aliceToken), ExpectedStatus: 200, ExpectedContent: []string{`"all_day":true`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "a timed series ends at a UTC date-time", Method: http.MethodPost, URL: eventsURL,
				Body: event(f.alice.Id, f.aliceCal, `,"rrule":"FREQ=DAILY;UNTIL=20261030T215959Z"`), Headers: auth(f.aliceToken),
				ExpectedStatus: 200, ExpectedContent: []string{`"rrule":"FREQ=DAILY;UNTIL=20261030T215959Z"`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "not at a date", Method: http.MethodPost, URL: eventsURL,
				Body: event(f.alice.Id, f.aliceCal, `,"rrule":"FREQ=DAILY;UNTIL=20261030"`), Headers: auth(f.aliceToken),
				ExpectedStatus: 400, ExpectedContent: []string{`validation_rrule_until`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "and an all-day series not at a date-time", Method: http.MethodPost, URL: eventsURL,
				Body: body(`{"owner":"` + f.alice.Id + `","calendar":"` + f.aliceCal + `","title":"Trip","all_day":true,` +
					`"start":"2026-10-24 00:00:00.000Z","end":"2026-10-25 00:00:00.000Z","rrule":"FREQ=WEEKLY;UNTIL=20261130T000000Z"}`),
				Headers: auth(f.aliceToken), ExpectedStatus: 400, ExpectedContent: []string{`validation_rrule_until`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "one default calendar per user, whatever its name", Method: http.MethodPost, URL: calendarsURL,
				Body:    body(`{"owner":"` + f.alice.Id + `","name":"Personnel","color":"green","is_default":true}`),
				Headers: auth(f.aliceToken), ExpectedStatus: 400, ExpectedContent: []string{`"status":400`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "other users have their own default", Method: http.MethodPost, URL: calendarsURL,
				Body:    body(`{"owner":"` + f.bob.Id + `","name":"Personal","color":"green","is_default":true}`),
				Headers: auth(f.bobToken), ExpectedStatus: 200, ExpectedContent: []string{`"is_default":true`},
			}
		},
		func(f *fixture) tests.ApiScenario {
			return tests.ApiScenario{
				Name: "the owner deletes an event", Method: http.MethodDelete, URL: eventsURL + "/" + f.aliceEvent.Id,
				Headers: auth(f.aliceToken), ExpectedStatus: 204,
			}
		},
	}
	for _, s := range scenarios {
		run(t, s)
	}
}

// Deleting a calendar deletes its events.
func TestDeletingACalendarDeletesItsEvents(t *testing.T) {
	f := newFixture(t)
	defer f.app.Cleanup()
	cal, _ := f.app.FindRecordById("calendars", f.aliceCal)
	if err := f.app.Delete(cal); err != nil {
		t.Fatal(err)
	}
	if _, err := f.app.FindRecordById("events", f.aliceEvent.Id); err == nil {
		t.Error("event of a deleted calendar still there")
	}
}
