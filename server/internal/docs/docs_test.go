package docs_test

import (
	"encoding/json"
	"net/http"
	"net/url"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tests"
	"github.com/pocketbase/pocketbase/tools/filesystem"

	"github.com/Paul-Carouge/Alcove/server/internal/docs"
	"github.com/Paul-Carouge/Alcove/server/internal/drive"
	"github.com/Paul-Carouge/Alcove/server/internal/media"
	"github.com/Paul-Carouge/Alcove/server/internal/media/mediatest"
	"github.com/Paul-Carouge/Alcove/server/internal/ocr"
	"github.com/Paul-Carouge/Alcove/server/internal/testutil"
)

type env struct {
	app        *tests.TestApp
	alice, bob *core.Record
	aliceTok   string
	bobTok     string
	ocrOn      bool
}

func setup(t *testing.T) *env {
	t.Helper()
	app := testutil.NewApp(t)
	t.Cleanup(app.Cleanup)
	drive.Register(app)
	media.Register(app)
	docs.Register(app, docs.Options{})
	e := &env{app: app, ocrOn: true}
	e.alice, e.aliceTok = testutil.User(t, app, "alice@test.local")
	e.bob, e.bobTok = testutil.User(t, app, "bob@test.local")
	return e
}

func needTools(t *testing.T, ocrToo bool) {
	t.Helper()
	tools := ocr.Detect()
	if !tools.CanReadPDF() || (ocrToo && (!tools.CanOCR() || !tools.PDFRender)) {
		t.Skip("poppler/tesseract not installed")
	}
}

func fixture(t *testing.T, name string) []byte {
	t.Helper()
	b, err := os.ReadFile("testdata/" + name)
	if err != nil {
		t.Fatal(err)
	}
	return b
}

// upload stores a file for owner and returns its document record, processed synchronously
// (media first, as the server does).
func (e *env) upload(t *testing.T, owner *core.Record, name string, content []byte) (*core.Record, *core.Record) {
	t.Helper()
	n := testutil.Node(t, e.app, owner, "", name, drive.KindFile)
	f, err := filesystem.NewFileFromBytes(content, name)
	if err != nil {
		t.Fatal(err)
	}
	n.Set("blob", f)
	if err := e.app.Save(n); err != nil {
		t.Fatal(err)
	}
	if m, err := e.app.FindFirstRecordByData(media.Collection, "node", n.Id); err == nil {
		if err := media.Process(e.app, m.Id); err != nil {
			t.Fatalf("media: %v", err)
		}
	}
	doc, err := e.app.FindFirstRecordByData(docs.Collection, "node", n.Id)
	if err != nil {
		return n, nil
	}
	if err := docs.Process(e.app, doc.Id, e.ocrOn); err != nil {
		t.Fatalf("process: %v", err)
	}
	doc, _ = e.app.FindRecordById(docs.Collection, doc.Id)
	return n, doc
}

type searchHit struct {
	Node struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"node"`
	Match   string `json:"match"`
	Snippet []struct {
		Text string `json:"text"`
		Hit  bool   `json:"hit"`
	} `json:"snippet"`
}

func (e *env) search(t *testing.T, token, q string) []searchHit {
	t.Helper()
	srv := testutil.Server(t, e.app)
	req, _ := http.NewRequest(http.MethodGet, srv.URL+"/api/v1/search?q="+url.QueryEscape(q), nil)
	req.Header.Set("Authorization", token)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatal(err)
	}
	defer func() { _ = res.Body.Close() }()
	if res.StatusCode != http.StatusOK {
		t.Fatalf("search %q: HTTP %d", q, res.StatusCode)
	}
	var body struct{ Items []searchHit }
	if err := json.NewDecoder(res.Body).Decode(&body); err != nil {
		t.Fatal(err)
	}
	return body.Items
}

func snippetText(h searchHit) (all, hits string) {
	for _, s := range h.Snippet {
		all += s.Text
		if s.Hit {
			hits += s.Text + "|"
		}
	}
	return all, hits
}

func TestKindOf(t *testing.T) {
	for mime, want := range map[string]string{
		"application/pdf":           docs.KindPDF,
		"text/plain; charset=utf-8": docs.KindText,
		"text/markdown":             docs.KindText,
		"image/png":                 docs.KindImage,
		"image/heic":                docs.KindImage,
		"image/svg+xml":             "",
		"text/html":                 "",
		"application/zip":           "",
		"video/mp4":                 "",
	} {
		if got := docs.KindOf(mime); got != want {
			t.Errorf("KindOf(%q) = %q, want %q", mime, got, want)
		}
	}
}

func TestTextFileIsIndexedAndSearchable(t *testing.T) {
	e := setup(t)
	n, doc := e.upload(t, e.alice, "notes.txt", []byte("Liste de courses\r\n\r\n\r\n\r\nPain, fromage et crème fraîche"))
	if doc == nil || doc.GetString("status") != "ready" || doc.GetString("method") != "text" {
		t.Fatalf("document = %v", doc)
	}
	if got := doc.GetString("text"); got != "Liste de courses\n\nPain, fromage et crème fraîche" {
		t.Errorf("text = %q", got)
	}

	// Accents and case do not matter; words are prefixes.
	hits := e.search(t, e.aliceTok, "CREME fromag")
	if len(hits) != 1 || hits[0].Node.ID != n.Id || hits[0].Match != "content" {
		t.Fatalf("hits = %+v", hits)
	}
	all, marked := snippetText(hits[0])
	if !strings.Contains(all, "Pain, fromage et crème fraîche") || marked != "fromage|crème|" {
		t.Errorf("snippet = %q, hits %q", all, marked)
	}

	// Another account finds nothing; operators are not interpreted.
	if hits := e.search(t, e.bobTok, "fromage"); len(hits) != 0 {
		t.Errorf("bob sees %+v", hits)
	}
	if hits := e.search(t, e.aliceTok, `fromage" OR "x`); len(hits) != 0 {
		t.Errorf("quotes were interpreted: %+v", hits)
	}

	// Names match first, by substring.
	hits = e.search(t, e.aliceTok, "otes")
	if len(hits) != 1 || hits[0].Match != "name" {
		t.Errorf("name hits = %+v", hits)
	}

	// Trashed files disappear from results; deleting the file removes its index row.
	n.Set("trashed_at", time.Now().UTC().Format(time.RFC3339))
	if err := e.app.Save(n); err != nil {
		t.Fatal(err)
	}
	if hits := e.search(t, e.aliceTok, "fromage"); len(hits) != 0 {
		t.Errorf("trashed file found: %+v", hits)
	}
	if err := e.app.Delete(n); err != nil {
		t.Fatal(err)
	}
	var rows int
	_ = e.app.DB().NewQuery("SELECT COUNT(*) FROM documents_fts").Row(&rows)
	if rows != 0 {
		t.Errorf("%d index rows left after delete", rows)
	}
}

func TestSearchValidation(t *testing.T) {
	e := setup(t)
	srv := testutil.Server(t, e.app)
	for _, q := range []string{"", strings.Repeat("a", 201)} {
		req, _ := http.NewRequest(http.MethodGet, srv.URL+"/api/v1/search?q="+url.QueryEscape(q), nil)
		req.Header.Set("Authorization", e.aliceTok)
		res, err := http.DefaultClient.Do(req)
		if err != nil {
			t.Fatal(err)
		}
		_ = res.Body.Close()
		if res.StatusCode != http.StatusBadRequest {
			t.Errorf("q=%d chars: HTTP %d", len(q), res.StatusCode)
		}
	}
	res, err := http.Get(srv.URL + "/api/v1/search?q=x")
	if err != nil {
		t.Fatal(err)
	}
	_ = res.Body.Close()
	if res.StatusCode != http.StatusUnauthorized {
		t.Errorf("anonymous search: HTTP %d", res.StatusCode)
	}
}

func TestPDFWithTextLayer(t *testing.T) {
	needTools(t, false)
	e := setup(t)
	e.ocrOn = false // a text layer needs no OCR
	_, doc := e.upload(t, e.alice, "contrat.pdf", fixture(t, "text.pdf"))
	if doc.GetString("status") != "ready" || doc.GetString("method") != "pdf" || doc.GetInt("pages") != 2 {
		t.Fatalf("document = %s %s %d (%s)", doc.GetString("status"), doc.GetString("method"), doc.GetInt("pages"), doc.GetString("error"))
	}
	if text := doc.GetString("text"); !strings.Contains(text, "Le dépôt de garantie") || !strings.Contains(text, "\f") {
		t.Errorf("text = %q", text)
	}
	if hits := e.search(t, e.aliceTok, "depot garantie"); len(hits) != 1 {
		t.Errorf("hits = %+v", hits)
	}
}

func TestScannedPDF(t *testing.T) {
	needTools(t, true)
	e := setup(t)
	e.ocrOn = false
	n, doc := e.upload(t, e.alice, "facture.pdf", fixture(t, "scan.pdf"))
	if doc.GetString("status") != "skipped" || doc.GetString("reason") != "ocr-off" {
		t.Fatalf("without OCR: %s %s", doc.GetString("status"), doc.GetString("reason"))
	}

	// Turned on: the same record is read again.
	doc.Set("status", "pending")
	if err := e.app.Save(doc); err != nil {
		t.Fatal(err)
	}
	if err := docs.Process(e.app, doc.Id, true); err != nil {
		t.Fatal(err)
	}
	doc, _ = e.app.FindRecordById(docs.Collection, doc.Id)
	if doc.GetString("status") != "ready" || doc.GetString("method") != "ocr" {
		t.Fatalf("with OCR: %s %s (%s)", doc.GetString("status"), doc.GetString("method"), doc.GetString("error"))
	}
	if !strings.Contains(doc.GetString("text"), "84,20") {
		t.Errorf("text = %q", doc.GetString("text"))
	}
	hits := e.search(t, e.aliceTok, "facture 2024")
	if len(hits) != 1 || hits[0].Node.ID != n.Id {
		t.Errorf("hits = %+v", hits)
	}
}

func TestScreenshotsAreReadButNotCameraPhotos(t *testing.T) {
	needTools(t, true)
	e := setup(t)
	_, doc := e.upload(t, e.alice, "capture.png", fixture(t, "scan.png"))
	if doc.GetString("status") != "ready" || doc.GetString("method") != "ocr" ||
		!strings.Contains(doc.GetString("text"), "ALC-5521") {
		t.Fatalf("screenshot: %s %s %q (%s)", doc.GetString("status"), doc.GetString("method"), doc.GetString("text"), doc.GetString("error"))
	}

	_, photo := e.upload(t, e.alice, "beach.jpg", mediatest.JPEG(mediatest.Photo{
		Width: 160, Height: 90, Taken: time.Now(), Make: "Canon", Model: "EOS R6",
	}))
	if photo.GetString("status") != "skipped" || photo.GetString("reason") != "photo" {
		t.Errorf("camera photo: %s %s", photo.GetString("status"), photo.GetString("reason"))
	}
}

func TestUsersCannotWriteDocuments(t *testing.T) {
	e := setup(t)
	_, doc := e.upload(t, e.alice, "a.txt", []byte("bonjour"))
	for _, s := range []tests.ApiScenario{
		{
			Name:            "owner reads",
			Method:          http.MethodGet,
			URL:             "/api/collections/documents/records/" + doc.Id,
			Headers:         map[string]string{"Authorization": e.aliceTok},
			ExpectedStatus:  200,
			ExpectedContent: []string{`"text":"bonjour"`},
		},
		{
			Name:            "others do not",
			Method:          http.MethodGet,
			URL:             "/api/collections/documents/records/" + doc.Id,
			Headers:         map[string]string{"Authorization": e.bobTok},
			ExpectedStatus:  404,
			ExpectedContent: []string{`"status":404`},
		},
		{
			Name:            "nobody writes",
			Method:          http.MethodPatch,
			URL:             "/api/collections/documents/records/" + doc.Id,
			Body:            strings.NewReader(`{"text":"forged"}`),
			Headers:         map[string]string{"Authorization": e.aliceTok},
			ExpectedStatus:  403,
			ExpectedContent: []string{`"status":403`},
		},
	} {
		s.TestAppFactory = func(testing.TB) *tests.TestApp { return e.app }
		s.DisableTestAppCleanup = true
		s.Test(t)
	}
}

func TestAdminOCR(t *testing.T) {
	e := setup(t)
	e.alice.Set("role", "admin")
	if err := e.app.Save(e.alice); err != nil {
		t.Fatal(err)
	}
	for _, s := range []tests.ApiScenario{
		{
			Name:            "users cannot read the OCR status",
			Method:          http.MethodGet,
			URL:             "/api/v1/admin/ocr",
			Headers:         map[string]string{"Authorization": e.bobTok},
			ExpectedStatus:  403,
			ExpectedContent: []string{`"status":403`},
		},
		{
			Name:            "admins can",
			Method:          http.MethodGet,
			URL:             "/api/v1/admin/ocr",
			Headers:         map[string]string{"Authorization": e.aliceTok},
			ExpectedStatus:  200,
			ExpectedContent: []string{`"enabled":true`, `"counts":`, `"canInstall":false`},
		},
		{
			Name:            "and turn it off",
			Method:          http.MethodPut,
			URL:             "/api/v1/admin/ocr",
			Body:            strings.NewReader(`{"enabled":false}`),
			Headers:         map[string]string{"Authorization": e.aliceTok},
			ExpectedStatus:  200,
			ExpectedContent: []string{`"enabled":false`},
		},
		{
			Name:            "the body is checked",
			Method:          http.MethodPut,
			URL:             "/api/v1/admin/ocr",
			Body:            strings.NewReader(`{}`),
			Headers:         map[string]string{"Authorization": e.aliceTok},
			ExpectedStatus:  400,
			ExpectedContent: []string{`"status":400`},
		},
		{
			Name:            "installing needs a native Linux service",
			Method:          http.MethodPost,
			URL:             "/api/v1/admin/ocr/install",
			Headers:         map[string]string{"Authorization": e.aliceTok},
			ExpectedStatus:  400,
			ExpectedContent: []string{`"status":400`},
		},
	} {
		s.TestAppFactory = func(testing.TB) *tests.TestApp { return e.app }
		s.DisableTestAppCleanup = true
		s.Test(t)
	}
}
