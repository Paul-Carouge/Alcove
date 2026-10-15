// Package calendar holds the invariants of the `calendars` and `events` collections (ADR 0028). Reads and
// writes go through PocketBase's record API and realtime, restricted to the owner by the collection rules.
package calendar

import (
	"regexp"

	"github.com/pocketbase/dbx"
	validation "github.com/pocketbase/ozzo-validation/v4"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/security"
)

// Module is the name advertised in /health.
const Module = "calendar"

const Events = "events"

var (
	errForeignCalendar = validation.Errors{"calendar": validation.NewError("validation_calendar_owner", "Unknown calendar.")}
	errEndBeforeStart  = validation.Errors{"end": validation.NewError("validation_end_before_start", "The end is before the start.")}
	errAllDayTime      = validation.Errors{"start": validation.NewError("validation_all_day_time", "All-day events start and end at midnight UTC.")}
	errUntilForm       = validation.Errors{"rrule": validation.NewError("validation_rrule_until", "UNTIL is a date for all-day events, a UTC date-time otherwise.")}

	untilDate     = regexp.MustCompile(`UNTIL=\d{8}$`)
	untilDateTime = regexp.MustCompile(`UNTIL=\d{8}T\d{6}Z$`)
)

// Register binds the model hooks of events.
func Register(app core.App) {
	check := func(e *core.RecordEvent) error {
		if err := Check(e.App, e.Record); err != nil {
			return err
		}
		return e.Next()
	}
	app.OnRecordCreate(Events).BindFunc(func(e *core.RecordEvent) error {
		if e.Record.GetString("uid") == "" {
			e.Record.Set("uid", security.RandomString(32)+"@alcove")
		}
		return check(e)
	})
	app.OnRecordUpdate(Events).BindFunc(check)
}

// Check validates an event: its calendar belongs to its owner (calendar ids are not secret, and the
// relation field alone would accept anyone's), it does not end before it starts, and an all-day event
// covers whole UTC dates.
func Check(app core.App, ev *core.Record) error {
	cal := ev.GetString("calendar")
	if ev.IsNew() || cal != ev.Original().GetString("calendar") {
		n, err := app.CountRecords("calendars", dbx.HashExp{"id": cal, "owner": ev.GetString("owner")})
		if err != nil {
			return err
		}
		if n != 1 {
			return errForeignCalendar
		}
	}
	// RFC 5545: UNTIL has the value type of DTSTART (a date for all-day events).
	if rrule := ev.GetString("rrule"); rrule != "" {
		allDay := ev.GetBool("all_day")
		if (allDay && untilDateTime.MatchString(rrule)) || (!allDay && untilDate.MatchString(rrule)) {
			return errUntilForm
		}
	}
	start, end := ev.GetDateTime("start").Time(), ev.GetDateTime("end").Time()
	if end.Before(start) {
		return errEndBeforeStart
	}
	if ev.GetBool("all_day") {
		for _, t := range []int{start.Hour(), start.Minute(), start.Second(), start.Nanosecond(), end.Hour(), end.Minute(), end.Second(), end.Nanosecond()} {
			if t != 0 {
				return errAllDayTime
			}
		}
		if !end.After(start) {
			return errEndBeforeStart
		}
	}
	return nil
}
