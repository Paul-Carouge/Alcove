// Package updater finds, verifies and installs new Alcove releases (ADR 0015).
// Releases carry SHA256SUMS signed with an Ed25519 key; nothing is installed
// unless both the signature and the archive checksum verify.
package updater

import (
	"archive/tar"
	"archive/zip"
	"bufio"
	"bytes"
	"compress/gzip"
	"context"
	"crypto/ed25519"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"regexp"
	"runtime"
	"strings"
	"time"

	"golang.org/x/mod/semver"
)

const (
	SumsAsset = "SHA256SUMS"
	SigAsset  = "SHA256SUMS.sig"
	// maxArchive bounds downloads (the binary is ~40 MB).
	maxArchive = 512 << 20
)

// Release is the subset of a GitHub release we use.
type Release struct {
	Version     string            `json:"version"`
	Notes       string            `json:"notes"`
	URL         string            `json:"url"`
	PublishedAt time.Time         `json:"publishedAt"`
	Assets      map[string]string `json:"-"` // name -> download URL
}

// Client talks to the GitHub releases API (or a compatible mirror).
type Client struct {
	APIBase   string // e.g. https://api.github.com
	Repo      string // owner/name
	PublicKey ed25519.PublicKey
	HTTP      *http.Client
}

// New builds a client; base64Key is the release signing public key.
func New(apiBase, repo, base64Key string) (*Client, error) {
	key, err := base64.StdEncoding.DecodeString(base64Key)
	if err != nil || len(key) != ed25519.PublicKeySize {
		return nil, errors.New("invalid release public key")
	}
	return &Client{
		APIBase: strings.TrimRight(apiBase, "/"), Repo: repo, PublicKey: key,
		HTTP: &http.Client{Timeout: 10 * time.Minute},
	}, nil
}

// Latest returns the newest published release.
func (c *Client) Latest(ctx context.Context) (*Release, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.APIBase+"/repos/"+c.Repo+"/releases/latest", nil)
	if err != nil {
		return nil, err
	}
	req.Header.Set("Accept", "application/vnd.github+json")
	res, err := c.HTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer func() { _ = res.Body.Close() }()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("release lookup: HTTP %d", res.StatusCode)
	}
	var gh struct {
		TagName     string    `json:"tag_name"`
		Body        string    `json:"body"`
		HTMLURL     string    `json:"html_url"`
		PublishedAt time.Time `json:"published_at"`
		Assets      []struct {
			Name string `json:"name"`
			URL  string `json:"browser_download_url"`
		} `json:"assets"`
	}
	if err := json.NewDecoder(io.LimitReader(res.Body, 4<<20)).Decode(&gh); err != nil {
		return nil, err
	}
	if !semver.IsValid(gh.TagName) {
		return nil, fmt.Errorf("unexpected release tag %q", gh.TagName)
	}
	r := &Release{
		Version: strings.TrimPrefix(gh.TagName, "v"), Notes: gh.Body, URL: gh.HTMLURL,
		PublishedAt: gh.PublishedAt, Assets: map[string]string{},
	}
	for _, a := range gh.Assets {
		r.Assets[a.Name] = a.URL
	}
	return r, nil
}

// describeSuffix matches git describe output after a tag ("-3-gabc123-dirty"):
// such builds come *after* the tag, unlike SemVer pre-releases.
var describeSuffix = regexp.MustCompile(`-\d+-g[0-9a-f]+(-dirty)?$|-dirty$`)

// Newer reports whether latest is a higher version than current. Development
// builds ("0.9.0-3-gabc") compare as their base version; builds without a
// usable version (e.g. a bare commit hash) count as 0.0.0.
func Newer(current, latest string) bool {
	cur := "v" + describeSuffix.ReplaceAllString(strings.TrimPrefix(current, "v"), "")
	if !semver.IsValid(cur) {
		cur = "v0.0.0"
	}
	lat := "v" + strings.TrimPrefix(latest, "v")
	return semver.IsValid(lat) && semver.Compare(lat, cur) > 0
}

// ArchiveName is the release asset for a platform.
func ArchiveName(version, goos, goarch string) string {
	ext := "tar.gz"
	if goos == "windows" {
		ext = "zip"
	}
	return fmt.Sprintf("alcove_%s_%s_%s.%s", strings.TrimPrefix(version, "v"), goos, goarch, ext)
}

// Platform returns the running GOOS and the asset arch (armv7 for GOARM=7).
func Platform() (string, string) {
	arch := runtime.GOARCH
	if arch == "arm" {
		arch = "armv7"
	}
	return runtime.GOOS, arch
}

func (c *Client) fetch(ctx context.Context, url string, limit int64) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
	if err != nil {
		return nil, err
	}
	res, err := c.HTTP.Do(req)
	if err != nil {
		return nil, err
	}
	defer func() { _ = res.Body.Close() }()
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("download %s: HTTP %d", path.Base(url), res.StatusCode)
	}
	b, err := io.ReadAll(io.LimitReader(res.Body, limit+1))
	if err != nil {
		return nil, err
	}
	if int64(len(b)) > limit {
		return nil, fmt.Errorf("download %s: too large", path.Base(url))
	}
	return b, nil
}

// VerifiedSums downloads SHA256SUMS and checks its Ed25519 signature.
func (c *Client) VerifiedSums(ctx context.Context, r *Release) (map[string]string, error) {
	sumsURL, sigURL := r.Assets[SumsAsset], r.Assets[SigAsset]
	if sumsURL == "" || sigURL == "" {
		return nil, errors.New("release is not signed (missing SHA256SUMS or its signature)")
	}
	sums, err := c.fetch(ctx, sumsURL, 1<<20)
	if err != nil {
		return nil, err
	}
	sigB64, err := c.fetch(ctx, sigURL, 4096)
	if err != nil {
		return nil, err
	}
	sig, err := base64.StdEncoding.DecodeString(strings.TrimSpace(string(sigB64)))
	if err != nil || !ed25519.Verify(c.PublicKey, sums, sig) {
		return nil, errors.New("SHA256SUMS signature is invalid: refusing to update")
	}
	return ParseSums(sums), nil
}

// ParseSums reads "<hex>  <name>" lines.
func ParseSums(b []byte) map[string]string {
	out := map[string]string{}
	sc := bufio.NewScanner(bytes.NewReader(b))
	for sc.Scan() {
		f := strings.Fields(sc.Text())
		if len(f) == 2 {
			out[strings.TrimPrefix(f[1], "*")] = strings.ToLower(f[0])
		}
	}
	return out
}

// Download fetches the archive for this platform, verifies it and extracts
// the executable into dir. It returns the extracted file path.
func (c *Client) Download(ctx context.Context, r *Release, dir string) (string, error) {
	goos, arch := Platform()
	name := ArchiveName(r.Version, goos, arch)
	url := r.Assets[name]
	if url == "" {
		return "", fmt.Errorf("no build for %s/%s in v%s", goos, arch, r.Version)
	}
	sums, err := c.VerifiedSums(ctx, r)
	if err != nil {
		return "", err
	}
	want, ok := sums[name]
	if !ok {
		return "", fmt.Errorf("%s is not listed in SHA256SUMS", name)
	}
	archive, err := c.fetch(ctx, url, maxArchive)
	if err != nil {
		return "", err
	}
	got := sha256.Sum256(archive)
	if hex.EncodeToString(got[:]) != want {
		return "", fmt.Errorf("checksum mismatch for %s: refusing to update", name)
	}
	exe := "alcove"
	if goos == "windows" {
		exe += ".exe"
	}
	data, err := extract(archive, strings.HasSuffix(name, ".zip"), exe)
	if err != nil {
		return "", err
	}
	out := filepath.Join(dir, exe+".new")
	if err := os.WriteFile(out, data, 0o755); err != nil { // #nosec G306 -- an executable
		return "", err
	}
	return out, nil
}

func extract(archive []byte, isZip bool, exe string) ([]byte, error) {
	if isZip {
		zr, err := zip.NewReader(bytes.NewReader(archive), int64(len(archive)))
		if err != nil {
			return nil, err
		}
		for _, f := range zr.File {
			if path.Base(f.Name) == exe && !f.FileInfo().IsDir() {
				rc, err := f.Open()
				if err != nil {
					return nil, err
				}
				defer func() { _ = rc.Close() }()
				return io.ReadAll(io.LimitReader(rc, maxArchive))
			}
		}
		return nil, fmt.Errorf("%s not found in archive", exe)
	}
	gz, err := gzip.NewReader(bytes.NewReader(archive))
	if err != nil {
		return nil, err
	}
	tr := tar.NewReader(gz)
	for {
		h, err := tr.Next()
		if err == io.EOF {
			return nil, fmt.Errorf("%s not found in archive", exe)
		}
		if err != nil {
			return nil, err
		}
		if h.Typeflag == tar.TypeReg && path.Base(h.Name) == exe {
			return io.ReadAll(io.LimitReader(tr, maxArchive))
		}
	}
}

// Replace swaps target with the new executable atomically, keeping the
// previous binary as target+".old" for rollback.
func Replace(target, newExe string) error {
	dir := filepath.Dir(target)
	staged := filepath.Join(dir, "."+filepath.Base(target)+".staged")
	if err := copyFile(newExe, staged); err != nil {
		return fmt.Errorf("stage new binary: %w", err)
	}
	old := target + ".old"
	_ = os.Remove(old)
	if err := os.Rename(target, old); err != nil {
		_ = os.Remove(staged)
		return fmt.Errorf("move current binary aside: %w", err)
	}
	if err := os.Rename(staged, target); err != nil {
		_ = os.Rename(old, target) // roll back
		return fmt.Errorf("install new binary: %w", err)
	}
	return nil
}

func copyFile(src, dst string) error {
	in, err := os.Open(src) // #nosec G304 -- path produced by Download
	if err != nil {
		return err
	}
	defer func() { _ = in.Close() }()
	out, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o755) // #nosec G302 G304 -- executable in the install dir
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		_ = out.Close()
		return err
	}
	return out.Close()
}
