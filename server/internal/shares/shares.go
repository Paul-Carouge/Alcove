// Package shares implements public links to drive nodes (see the "shares"
// and "public" tags in packages/api-spec/openapi.yaml).
package shares

import (
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"net/http"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/pocketbase/pocketbase/apis"
	"github.com/pocketbase/pocketbase/core"
	"github.com/pocketbase/pocketbase/tools/security"
	"github.com/pocketbase/pocketbase/tools/types"
	"golang.org/x/crypto/bcrypt"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

const (
	Collection = "shares"

	maxLifetime = 366 * 24 * time.Hour
	accessTTL   = time.Hour
	bcryptCost  = 12
	// maxDepth bounds ancestor walks (folder shares).
	maxDepth = 256
)

// Register mounts the owner and public routes.
func Register(app core.App) {
	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.POST("/api/v1/shares", create).Bind(apis.RequireAuth("users"))
		pub := se.Router.Group("/api/v1/public/shares/{token}")
		pub.GET("", describe)
		pub.POST("/unlock", unlock)
		pub.GET("/files/{nodeId}", downloadFile)
		return se.Next()
	})
}

// newToken returns a 256-bit URL-safe link token and its SHA-256 (stored).
func newToken() (token, hash string, err error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", "", err
	}
	token = base64.RawURLEncoding.EncodeToString(b)
	return token, hashToken(token), nil
}

func hashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

type createBody struct {
	Node      string `json:"node"`
	ExpiresAt string `json:"expiresAt"`
	Password  string `json:"password"`
}

func create(e *core.RequestEvent) error {
	var body createBody
	if err := e.BindBody(&body); err != nil {
		return e.BadRequestError("Invalid body.", err)
	}
	node, err := e.App.FindRecordById(drive.Collection, body.Node)
	if err != nil || node.GetString("owner") != e.Auth.Id || !node.GetDateTime("trashed_at").IsZero() {
		return e.BadRequestError("Unknown node.", nil)
	}

	var expires types.DateTime
	if body.ExpiresAt != "" {
		t, err := time.Parse(time.RFC3339, body.ExpiresAt)
		now := time.Now()
		if err != nil || !t.After(now) || t.After(now.Add(maxLifetime)) {
			return e.BadRequestError("expiresAt must be a future RFC 3339 date within one year.", nil)
		}
		expires, _ = types.ParseDateTime(t.UTC())
	}
	if n := len(body.Password); n > 0 && (n < 4 || n > 256) {
		return e.BadRequestError("The password must be 4 to 256 characters long.", nil)
	}

	token, hash, err := newToken()
	if err != nil {
		return err
	}
	col, err := e.App.FindCollectionByNameOrId(Collection)
	if err != nil {
		return err
	}
	share := core.NewRecord(col)
	share.Set("node", node.Id)
	share.Set("created_by", e.Auth.Id)
	share.Set("token_hash", hash)
	share.Set("access_secret", security.RandomString(48))
	share.Set("expires_at", expires)
	if body.Password != "" {
		pw, err := bcrypt.GenerateFromPassword([]byte(body.Password), bcryptCost)
		if err != nil {
			return err
		}
		share.Set("password_hash", string(pw))
		share.Set("has_password", true)
	}
	if err := e.App.Save(share); err != nil {
		return err
	}

	var expiresOut any
	if !expires.IsZero() {
		expiresOut = expires.Time().Format(time.RFC3339)
	}
	return e.JSON(http.StatusCreated, map[string]any{
		"id": share.Id, "token": token, "expiresAt": expiresOut, "hasPassword": body.Password != "",
	})
}

var (
	errGone     = errors.New("expired")
	errNotFound = errors.New("not found")
	errLocked   = errors.New("password required")
)

// resolve finds an active share and its (non-trashed) root node.
func resolve(app core.App, token string) (share, root *core.Record, err error) {
	share, err = app.FindFirstRecordByData(Collection, "token_hash", hashToken(token))
	if err != nil {
		return nil, nil, errNotFound
	}
	if exp := share.GetDateTime("expires_at"); !exp.IsZero() && time.Now().After(exp.Time()) {
		return nil, nil, errGone
	}
	root, err = app.FindRecordById(drive.Collection, share.GetString("node"))
	if err != nil || !root.GetDateTime("trashed_at").IsZero() {
		return nil, nil, errNotFound
	}
	return share, root, nil
}

// checkAccess validates the unlock token of password-protected shares.
func checkAccess(share *core.Record, access string) error {
	if !share.GetBool("has_password") {
		return nil
	}
	if access == "" {
		return errLocked
	}
	claims, err := security.ParseJWT(access, share.GetString("access_secret"))
	if err != nil || claims["share"] != share.Id {
		return errLocked
	}
	return nil
}

func fail(e *core.RequestEvent, err error) error {
	switch {
	case errors.Is(err, errGone):
		return e.Error(http.StatusGone, "This link has expired.", nil)
	case errors.Is(err, errLocked):
		// Written directly: PocketBase rewrites ApiError data into validation errors.
		return e.JSON(http.StatusUnauthorized, map[string]any{
			"status": http.StatusUnauthorized, "message": "This link is password protected.",
			"data": map[string]any{"requiresPassword": true},
		})
	default:
		return e.NotFoundError("", nil)
	}
}

// open resolves the share and enforces the password for public reads.
func open(e *core.RequestEvent) (share, root *core.Record, err error) {
	share, root, err = resolve(e.App, e.Request.PathValue("token"))
	if err == nil {
		err = checkAccess(share, e.Request.URL.Query().Get("access"))
	}
	return share, root, err
}

// within walks up from node to the share root; it returns the chain from the
// root down to node, or false if node is outside the share or trashed.
func within(app core.App, root *core.Record, node *core.Record) ([]*core.Record, bool) {
	chain := []*core.Record{}
	current := node
	for range maxDepth {
		if !current.GetDateTime("trashed_at").IsZero() {
			return nil, false
		}
		chain = append([]*core.Record{current}, chain...)
		if current.Id == root.Id {
			return chain, true
		}
		parent := current.GetString("parent")
		if parent == "" {
			return nil, false
		}
		next, err := app.FindRecordById(drive.Collection, parent)
		if err != nil {
			return nil, false
		}
		current = next
	}
	return nil, false
}

func publicNode(n *core.Record) map[string]any {
	return map[string]any{
		"id": n.Id, "name": n.GetString("name"), "kind": n.GetString("kind"),
		"size": n.GetInt("size"), "mime": n.GetString("mime"), "updated": n.GetString("updated"),
	}
}

func expiresOf(share *core.Record) any {
	if exp := share.GetDateTime("expires_at"); !exp.IsZero() {
		return exp.Time().Format(time.RFC3339)
	}
	return nil
}

func describe(e *core.RequestEvent) error {
	share, root, err := open(e)
	if err != nil {
		return fail(e, err)
	}
	e.Response.Header().Set("Cache-Control", "no-store")
	res := map[string]any{"item": publicNode(root), "expiresAt": expiresOf(share)}
	if root.GetString("kind") != drive.KindFolder {
		return e.JSON(http.StatusOK, res)
	}

	folder := root
	if id := e.Request.URL.Query().Get("folder"); id != "" && id != root.Id {
		folder, err = e.App.FindRecordById(drive.Collection, id)
		if err != nil || folder.GetString("kind") != drive.KindFolder {
			return e.NotFoundError("", nil)
		}
	}
	chain, ok := within(e.App, root, folder)
	if !ok {
		return e.NotFoundError("", nil)
	}
	children, err := e.App.FindRecordsByFilter(drive.Collection,
		"parent = {:parent} && trashed_at = ''", "name", 2000, 0, map[string]any{"parent": folder.Id})
	if err != nil {
		return err
	}
	path := make([]map[string]any, len(chain))
	for i, n := range chain {
		path[i] = publicNode(n)
	}
	list := make([]map[string]any, len(children))
	for i, n := range children {
		list[i] = publicNode(n)
	}
	res["folder"], res["path"], res["children"] = publicNode(folder), path, list
	return e.JSON(http.StatusOK, res)
}

func unlock(e *core.RequestEvent) error {
	share, _, err := resolve(e.App, e.Request.PathValue("token"))
	if err != nil {
		return fail(e, err)
	}
	var body struct {
		Password string `json:"password"`
	}
	if err := e.BindBody(&body); err != nil || body.Password == "" || len(body.Password) > 256 {
		return e.BadRequestError("A password is required.", nil)
	}
	if !share.GetBool("has_password") ||
		bcrypt.CompareHashAndPassword([]byte(share.GetString("password_hash")), []byte(body.Password)) != nil {
		return e.UnauthorizedError("Wrong password.", nil)
	}
	access, err := security.NewJWT(jwt.MapClaims{"share": share.Id}, share.GetString("access_secret"), accessTTL)
	if err != nil {
		return err
	}
	return e.JSON(http.StatusOK, map[string]any{
		"access": access, "expiresAt": time.Now().Add(accessTTL).UTC().Format(time.RFC3339),
	})
}

func downloadFile(e *core.RequestEvent) error {
	_, root, err := open(e)
	if err != nil {
		return fail(e, err)
	}
	node, err := e.App.FindRecordById(drive.Collection, e.Request.PathValue("nodeId"))
	if err != nil || node.GetString("kind") != drive.KindFile || node.GetString("blob") == "" {
		return e.NotFoundError("", nil)
	}
	if _, ok := within(e.App, root, node); !ok {
		return e.NotFoundError("", nil)
	}
	return drive.Serve(e, node, e.Request.URL.Query().Get("inline") == "1")
}
