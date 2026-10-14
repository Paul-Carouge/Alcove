package media

import (
	"net/http"
	"sort"
	"time"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"
)

const (
	// memoryWindow: photos taken this many days around the anniversary count as "on this day".
	memoryWindow = 1
	// memoryPerYear bounds each group (the client shows a strip).
	memoryPerYear  = 24
	maxMemoryYears = 30
)

type memory struct {
	YearsAgo int            `json:"yearsAgo"`
	Year     int            `json:"year"`
	Items    []*core.Record `json:"items"`
}

// memories returns the caller's photos and videos taken around today's date in previous years
// ("1 year ago today"), newest year first. The client sends its own date (?date=YYYY-MM-DD) so the
// day follows the user's time zone, not the server's.
func memories(e *core.RequestEvent) error {
	today := time.Now()
	if d := e.Request.URL.Query().Get("date"); d != "" {
		parsed, err := time.Parse(time.DateOnly, d)
		if err != nil {
			return e.BadRequestError("date must be YYYY-MM-DD.", nil)
		}
		today = parsed
	}
	days := map[string]bool{}
	for off := -memoryWindow; off <= memoryWindow; off++ {
		days[today.AddDate(0, 0, off).Format("01-02")] = true
	}
	in := make([]any, 0, len(days))
	for d := range days {
		in = append(in, d)
	}
	firstYear := today.Year() - maxMemoryYears

	var recs []*core.Record
	err := e.App.RecordQuery(Collection).
		InnerJoin("nodes n", dbx.NewExp("n.id = media.node")).
		AndWhere(dbx.HashExp{"media.owner": e.Auth.Id, "media.status": "ready"}).
		AndWhere(dbx.NewExp("n.trashed_at = ''")).
		AndWhere(dbx.In("substr(media.taken_at, 6, 5)", in...)).
		AndWhere(dbx.NewExp("CAST(substr(media.taken_at, 1, 4) AS INTEGER) BETWEEN {:from} AND {:to}",
			dbx.Params{"from": firstYear, "to": today.Year() - 1})).
		OrderBy("media.taken_at DESC").
		Limit(2000).
		All(&recs)
	if err != nil {
		return err
	}
	byYear := map[int]*memory{}
	for _, r := range recs {
		y := r.GetDateTime("taken_at").Time().Year()
		g := byYear[y]
		if g == nil {
			g = &memory{YearsAgo: today.Year() - y, Year: y}
			byYear[y] = g
		}
		if len(g.Items) < memoryPerYear {
			g.Items = append(g.Items, r)
		}
	}
	out := make([]*memory, 0, len(byYear))
	all := make([]*core.Record, 0, len(recs))
	for _, g := range byYear {
		out = append(out, g)
		all = append(all, g.Items...)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].YearsAgo < out[j].YearsAgo })
	if errs := e.App.ExpandRecords(all, []string{"node"}, nil); len(errs) > 0 {
		e.App.Logger().Debug("memories: node expand failed", "errors", errs)
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, map[string]any{"memories": out})
}
