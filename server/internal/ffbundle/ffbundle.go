// Package ffbundle installs and activates the self-contained ffmpeg that releases ship for native
// Linux installs (ADR 0017). Distribution packages are often too old for phone photos (HEIC needs
// ffmpeg 7.1+), so Alcove keeps its own copy next to its binary, verified like the binary itself.
package ffbundle

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path"
	"path/filepath"
	"regexp"
	"runtime"
	"strconv"
	"strings"

	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

const (
	sumFile = ".sha256"
	// maxFile bounds a single extracted file (libavcodec is ~16 MB).
	maxFile = 256 << 20
)

// Supported reports whether releases ship a bundle for this system.
func Supported() bool { return runtime.GOOS == "linux" }

// AssetName is the release asset for an architecture (amd64, arm64, armv7).
func AssetName(arch string) string { return "ffmpeg_linux_" + arch + ".tar.gz" }

// Dir is where the bundle lives for a given Alcove binary.
func Dir(exe string) string { return filepath.Join(filepath.Dir(exe), "ffmpeg") }

// Installed returns the checksum of the installed bundle, or "" if there is none.
func Installed(dir string) string {
	b, err := os.ReadFile(filepath.Join(dir, sumFile)) // #nosec G304 -- our own install directory
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(b))
}

// Activate puts the bundle first on PATH when it is installed next to exe, so that every
// "ffmpeg"/"ffprobe" call of the process uses it. It reports whether it did.
func Activate(exe string) bool {
	dir := Dir(exe)
	if Installed(dir) == "" {
		return false
	}
	bin := filepath.Join(dir, "bin")
	_ = os.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	return true
}

var versionRe = regexp.MustCompile(`ffmpeg version n?(\d+)\.(\d+)`)

// ParseVersion reads "ffmpeg version 6.1.1-3ubuntu5 …"; ok is false for git builds ("N-…").
func ParseVersion(out string) (major, minor int, ok bool) {
	m := versionRe.FindStringSubmatch(out)
	if m == nil {
		return 0, 0, false
	}
	major, _ = strconv.Atoi(m[1])
	minor, _ = strconv.Atoi(m[2])
	return major, minor, true
}

// Version describes the ffmpeg found on PATH.
type Version struct {
	Found        bool
	Known        bool // false for git builds, assumed recent
	Major, Minor int
}

// Recent reports whether it decodes phone HEIC photos (tiled HEIF, ffmpeg 7.1+).
func (v Version) Recent() bool {
	return v.Found && (!v.Known || v.Major > 7 || (v.Major == 7 && v.Minor >= 1))
}

func (v Version) String() string {
	switch {
	case !v.Found:
		return "not installed"
	case !v.Known:
		return "development build"
	}
	return fmt.Sprintf("%d.%d", v.Major, v.Minor)
}

// System returns the version of the ffmpeg found on PATH.
func System() Version {
	if _, err := exec.LookPath("ffprobe"); err != nil {
		return Version{}
	}
	out, err := exec.Command("ffmpeg", "-hide_banner", "-version").Output() // #nosec G204 -- fixed arguments
	if err != nil {
		return Version{}
	}
	major, minor, ok := ParseVersion(string(out))
	return Version{Found: true, Known: ok, Major: major, Minor: minor}
}

// Wanted reports whether exe should use the bundle: it already does (keep it current), or the
// system ffmpeg is missing or too old.
func Wanted(exe string) bool {
	return Supported() && (Installed(Dir(exe)) != "" || !System().Recent())
}

// Install downloads the bundle of release r, verifies it against the signed checksums and installs
// it in dir, replacing an older one. It does nothing when the same bundle is already there.
func Install(ctx context.Context, c *updater.Client, r *updater.Release, dir string) (changed bool, err error) {
	_, arch := updater.Platform()
	name := AssetName(arch)
	if r.Assets[name] == "" {
		return false, fmt.Errorf("v%s has no ffmpeg for linux/%s", r.Version, arch)
	}
	sums, err := c.VerifiedSums(ctx, r)
	if err != nil {
		return false, err
	}
	if Installed(dir) == sums[name] {
		return false, nil
	}
	archive, err := c.FetchAsset(ctx, r, name, sums)
	if err != nil {
		return false, err
	}
	staged := dir + ".new"
	_ = os.RemoveAll(staged)
	if err := Extract(archive, staged); err != nil {
		_ = os.RemoveAll(staged)
		return false, err
	}
	if err := os.WriteFile(filepath.Join(staged, sumFile), []byte(sums[name]+"\n"), 0o644); err != nil { // #nosec G306 -- not secret
		_ = os.RemoveAll(staged)
		return false, err
	}
	// Running ffmpeg processes keep their files open: swapping directories is safe.
	old := dir + ".old"
	_ = os.RemoveAll(old)
	if _, err := os.Stat(dir); err == nil {
		if err := os.Rename(dir, old); err != nil {
			_ = os.RemoveAll(staged)
			return false, err
		}
	}
	if err := os.Rename(staged, dir); err != nil {
		_ = os.Rename(old, dir)
		return false, err
	}
	_ = os.RemoveAll(old)
	return true, nil
}

// Extract unpacks a bundle archive (a top-level "ffmpeg/" directory) into dir. Only regular files
// and directories inside it are accepted.
func Extract(archive []byte, dir string) error {
	gz, err := gzip.NewReader(bytes.NewReader(archive))
	if err != nil {
		return err
	}
	tr := tar.NewReader(gz)
	found := false
	for {
		h, err := tr.Next()
		if errors.Is(err, io.EOF) {
			break
		}
		if err != nil {
			return err
		}
		name := path.Clean(h.Name)
		rel, ok := strings.CutPrefix(name, "ffmpeg/")
		if name == "ffmpeg" {
			continue
		}
		if !ok || rel == "" || strings.HasPrefix(rel, "../") || path.IsAbs(rel) {
			return fmt.Errorf("unexpected path %q in ffmpeg archive", h.Name)
		}
		target := filepath.Join(dir, filepath.FromSlash(rel))
		switch h.Typeflag {
		case tar.TypeDir:
			if err := os.MkdirAll(target, 0o755); err != nil { // #nosec G301 -- program files
				return err
			}
		case tar.TypeReg:
			if h.Size > maxFile {
				return fmt.Errorf("%s is too large", h.Name)
			}
			if err := os.MkdirAll(filepath.Dir(target), 0o755); err != nil { // #nosec G301 -- program files
				return err
			}
			mode := os.FileMode(0o644)
			if h.Mode&0o111 != 0 {
				mode = 0o755
			}
			f, err := os.OpenFile(target, os.O_CREATE|os.O_WRONLY|os.O_EXCL, mode) // #nosec G304 -- path checked above
			if err != nil {
				return err
			}
			_, err = io.Copy(f, io.LimitReader(tr, maxFile))
			if cerr := f.Close(); err == nil {
				err = cerr
			}
			if err != nil {
				return err
			}
			found = found || rel == "bin/ffmpeg"
		default:
			return fmt.Errorf("unexpected entry type for %q in ffmpeg archive", h.Name)
		}
	}
	if !found {
		return errors.New("ffmpeg archive has no bin/ffmpeg")
	}
	return nil
}
