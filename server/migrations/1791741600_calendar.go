package migrations

import (
	"github.com/pocketbase/pocketbase/core"
	m "github.com/pocketbase/pocketbase/migrations"
	"github.com/pocketbase/pocketbase/tools/types"
)

// RRulePattern is the recurrence subset clients can expand (ADR 0028): one frequency, then an optional
// COUNT or UNTIL (a date for all-day events, a UTC date-time otherwise).
const RRulePattern = `^FREQ=(DAILY|WEEKLY|MONTHLY|YEARLY)(;(COUNT=[1-9][0-9]{0,2}|UNTIL=[0-9]{8}(T[0-9]{6}Z)?))?$`

// Calendar (ADR 0028): per-user calendars and their events, owner-only. Times are UTC instants; all-day
// events span whole UTC dates (end exclusive, like iCalendar's DTEND). internal/calendar checks that an
// event's calendar belongs to its owner and fills the iCalendar uid.
func init() {
	m.Register(func(app core.App) error {
		users, err := app.FindCollectionByNameOrId("users")
		if err != nil {
			return err
		}
		const owned = `owner = @request.auth.id`
		const create = `@request.auth.collectionName = "users" && @request.body.owner = @request.auth.id`

		cals := core.NewBaseCollection("calendars")
		cals.Fields.Add(
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "name", Required: true, Min: 1, Max: 60, Pattern: `^[^\x00-\x1f\x7f]*\S[^\x00-\x1f\x7f]*$`},
			&core.SelectField{Name: "color", Required: true, MaxSelect: 1, Values: TagColors},
			// The calendar clients create on the first visit (named in the user's language).
			&core.BoolField{Name: "is_default"},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		cals.ListRule = types.Pointer(owned)
		cals.ViewRule = types.Pointer(owned)
		cals.CreateRule = types.Pointer(create)
		cals.UpdateRule = types.Pointer(owned + ` && @request.body.owner:isset = false`)
		cals.DeleteRule = types.Pointer(owned)
		cals.AddIndex("idx_calendars_owner_name", true, "owner, name COLLATE NOCASE", "")
		// One default calendar per user: two devices creating it at once (in different languages,
		// so with different names) end with one, the second create fails.
		cals.AddIndex("idx_calendars_owner_default", true, "owner", "is_default = TRUE")
		if err := app.Save(cals); err != nil {
			return err
		}

		events := core.NewBaseCollection("events")
		events.Fields.Add(
			&core.RelationField{Name: "owner", CollectionId: users.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.RelationField{Name: "calendar", CollectionId: cals.Id, Required: true, MaxSelect: 1, CascadeDelete: true},
			&core.TextField{Name: "title", Required: true, Max: 200},
			&core.TextField{Name: "description", Max: 10000},
			&core.TextField{Name: "location", Max: 500},
			&core.DateField{Name: "start", Required: true},
			&core.DateField{Name: "end", Required: true},
			&core.BoolField{Name: "all_day"},
			&core.TextField{Name: "rrule", Max: 100, Pattern: RRulePattern},
			&core.TextField{Name: "uid", Max: 255},
			&core.AutodateField{Name: "created", OnCreate: true},
			&core.AutodateField{Name: "updated", OnCreate: true, OnUpdate: true},
		)
		events.ListRule = types.Pointer(owned)
		events.ViewRule = types.Pointer(owned)
		events.CreateRule = types.Pointer(create)
		events.UpdateRule = types.Pointer(owned + ` && @request.body.owner:isset = false && @request.body.uid:isset = false`)
		events.DeleteRule = types.Pointer(owned)
		events.AddIndex("idx_events_owner_start", false, "owner, start", "")
		events.AddIndex("idx_events_calendar", false, "calendar", "")
		events.AddIndex("idx_events_owner_uid", true, "owner, uid", "")
		return app.Save(events)
	}, func(app core.App) error {
		for _, name := range []string{"events", "calendars"} {
			c, err := app.FindCollectionByNameOrId(name)
			if err != nil {
				return err
			}
			if err := app.Delete(c); err != nil {
				return err
			}
		}
		return nil
	})
}
