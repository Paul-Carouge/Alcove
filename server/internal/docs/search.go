package docs

import (
	"net/http"
	"regexp"
	"strings"
	"unicode"

	"github.com/pocketbase/dbx"
	"github.com/pocketbase/pocketbase/core"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

const (
	ftsTable = "documents_fts"
	// Snippet markers: control characters that cannot appear in cleaned text.
	markOpen  = "\x02"
	markClose = "\x03"
	maxQuery  = 200
	maxHits   = 50
)

var whitespace = regexp.MustCompile(`\s+`)

// index (re)writes the full-text row of a ready document.
func index(app core.App, rec *core.Record, name string) {
	unindex(app, rec.Id)
	_, err := app.DB().Insert(ftsTable, dbx.Params{
		"doc":   rec.Id,
		"owner": rec.GetString("owner"),
		"name":  name,
		"body":  rec.GetString("text"),
	}).Execute()
	if err != nil {
		app.Logger().Error("cannot index document", "document", rec.Id, "error", err)
	}
}

func unindex(app core.App, id string) {
	_, _ = app.DB().Delete(ftsTable, dbx.HashExp{"doc": id}).Execute()
}

// prune removes index rows whose document is gone (deleted with its owner or folder).
func prune(app core.App) {
	_, _ = app.DB().NewQuery("DELETE FROM " + ftsTable + " WHERE doc NOT IN (SELECT id FROM " + Collection + ")").Execute()
}

// ftsQuery turns what the user typed into an FTS5 query: every word must appear, as a prefix
// ("fact" finds "facture"). Operators and quotes typed by the user are not interpreted.
func ftsQuery(q string) string {
	words := strings.FieldsFunc(q, func(r rune) bool { return !unicode.IsLetter(r) && !unicode.IsDigit(r) })
	if len(words) > 8 {
		words = words[:8]
	}
	parts := make([]string, 0, len(words))
	for _, w := range words {
		parts = append(parts, `"`+w+`"*`)
	}
	return strings.Join(parts, " ")
}

// Segment is part of a snippet; Hit marks the words that matched.
type Segment struct {
	Text string `json:"text"`
	Hit  bool   `json:"hit,omitempty"`
}

// segments splits a snippet with markers into plain and matching parts.
func segments(s string) []Segment {
	var out []Segment
	for s != "" {
		i := strings.Index(s, markOpen)
		if i < 0 {
			out = append(out, Segment{Text: s})
			break
		}
		if i > 0 {
			out = append(out, Segment{Text: s[:i]})
		}
		s = s[i+len(markOpen):]
		j := strings.Index(s, markClose)
		if j < 0 {
			out = append(out, Segment{Text: s, Hit: true})
			break
		}
		out = append(out, Segment{Text: s[:j], Hit: true})
		s = s[j+len(markClose):]
	}
	for i := range out {
		out[i].Text = whitespace.ReplaceAllString(out[i].Text, " ")
	}
	return out
}

type hit struct {
	Node    *core.Record `json:"node"`
	Match   string       `json:"match"` // name, tag or content
	Snippet []Segment    `json:"snippet,omitempty"`
	Tag     string       `json:"tag,omitempty"` // the matching tag's name
}

// search finds the user's files and folders by name, then by tag, then documents by content.
func (d *Docs) search(e *core.RequestEvent) error {
	q := strings.TrimSpace(e.Request.URL.Query().Get("q"))
	if q == "" || len([]rune(q)) > maxQuery {
		return e.BadRequestError("q must be 1 to 200 characters.", nil)
	}
	owner := e.Auth.Id

	// Names: substring match, folders first.
	var byName []*core.Record
	like := "%" + strings.NewReplacer(`\`, `\\`, `%`, `\%`, `_`, `\_`).Replace(q) + "%"
	err := e.App.RecordQuery(drive.Collection).
		AndWhere(dbx.HashExp{"owner": owner, "trashed_at": ""}).
		AndWhere(dbx.NewExp(`name LIKE {:like} ESCAPE '\'`, dbx.Params{"like": like})).
		OrderBy("kind DESC", "name ASC").
		Limit(maxHits).
		All(&byName)
	if err != nil {
		return err
	}
	seen := map[string]bool{}
	hits := make([]hit, 0, len(byName))
	for _, n := range byName {
		seen[n.Id] = true
		hits = append(hits, hit{Node: n, Match: "name"})
	}

	// Tags: files carrying a tag whose name starts with what was typed ("fact" → "Factures").
	var tags []struct {
		ID   string `db:"id"`
		Name string `db:"name"`
	}
	err = e.App.DB().Select("id", "name").From("tags").
		AndWhere(dbx.HashExp{"owner": owner}).
		AndWhere(dbx.NewExp(`name LIKE {:prefix} ESCAPE '\'`, dbx.Params{"prefix": strings.TrimSuffix(like, "%")[1:] + "%"})).
		OrderBy("name").Limit(5).All(&tags)
	if err != nil {
		return err
	}
	for _, t := range tags {
		var tagged []*core.Record
		err := e.App.RecordQuery(drive.Collection).
			AndWhere(dbx.HashExp{"owner": owner, "trashed_at": ""}).
			AndWhere(dbx.NewExp(`EXISTS (SELECT 1 FROM json_each(nodes.tags) WHERE value = {:tag})`, dbx.Params{"tag": t.ID})).
			OrderBy("kind DESC", "name ASC").
			Limit(maxHits).
			All(&tagged)
		if err != nil {
			return err
		}
		for _, n := range tagged {
			if !seen[n.Id] {
				seen[n.Id] = true
				hits = append(hits, hit{Node: n, Match: "tag", Tag: t.Name})
			}
		}
	}

	// Content: full-text, best matches first.
	if fq := ftsQuery(q); fq != "" {
		var rows []struct {
			Node    string `db:"node"`
			Snippet string `db:"snippet"`
		}
		err := e.App.DB().NewQuery(`
			SELECT d.node AS node, snippet(` + ftsTable + `, 3, {:open}, {:close}, '…', 16) AS snippet
			FROM ` + ftsTable + ` f
			JOIN ` + Collection + ` d ON d.id = f.doc
			JOIN nodes n ON n.id = d.node
			WHERE ` + ftsTable + ` MATCH {:q} AND f.owner = {:owner} AND n.trashed_at = ''
			ORDER BY bm25(` + ftsTable + `, 0, 0, 3, 1)
			LIMIT {:limit}`).
			Bind(dbx.Params{"q": fq, "owner": owner, "open": markOpen, "close": markClose, "limit": maxHits}).
			All(&rows)
		if err != nil {
			return err
		}
		ids := make([]string, 0, len(rows))
		for _, r := range rows {
			if !seen[r.Node] {
				ids = append(ids, r.Node)
			}
		}
		nodes, err := e.App.FindRecordsByIds(drive.Collection, ids)
		if err != nil {
			return err
		}
		byID := make(map[string]*core.Record, len(nodes))
		for _, n := range nodes {
			byID[n.Id] = n
		}
		for _, r := range rows {
			n := byID[r.Node]
			if n == nil || seen[r.Node] {
				continue
			}
			seen[r.Node] = true
			hits = append(hits, hit{Node: n, Match: "content", Snippet: segments(r.Snippet)})
		}
	}

	records := make([]*core.Record, len(hits))
	for i, h := range hits {
		records[i] = h.Node
	}
	if errs := e.App.ExpandRecords(records, []string{"parent"}, nil); len(errs) > 0 {
		e.App.Logger().Debug("search: parent expand failed", "errors", errs)
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	return e.JSON(http.StatusOK, map[string]any{"items": hits})
}
