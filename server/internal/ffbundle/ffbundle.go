// Package ffbundle installs and activates the self-contained ffmpeg that releases ship for native
// Linux installs (ADR 0017). Distribution packages are often too old for phone photos (HEIC needs
// ffmpeg 7.1+), so Alcove keeps its own copy next to its binary, verified like the binary itself.
package ffbundle

import (
	"context"
	"fmt"
	"os/exec"
	"regexp"
	"strconv"

	"github.com/Paul-Carouge/Alcove/server/internal/toolbundle"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

// Bundle is the ffmpeg bundle.
var Bundle = toolbundle.Bundle{Name: "ffmpeg", Probe: "bin/ffmpeg"}

// Supported reports whether releases ship a bundle for this system.
func Supported() bool { return toolbundle.Supported() }

// AssetName is the release asset for an architecture (amd64, arm64, armv7).
func AssetName(arch string) string { return Bundle.AssetName(arch) }

// Dir is where the bundle lives for a given Alcove binary.
func Dir(exe string) string { return Bundle.Dir(exe) }

// Installed returns the checksum of the installed bundle, or "" if there is none.
func Installed(dir string) string { return toolbundle.Installed(dir) }

// Activate puts the bundle first on PATH when it is installed next to exe, so that every
// "ffmpeg"/"ffprobe" call of the process uses it. It reports whether it did.
func Activate(exe string) bool { return Bundle.Activate(exe) }

// Install downloads the bundle of release r, verifies it against the signed checksums and installs
// it in dir, replacing an older one. It does nothing when the same bundle is already there.
func Install(ctx context.Context, c *updater.Client, r *updater.Release, dir string) (bool, error) {
	return Bundle.Install(ctx, c, r, dir)
}

// Extract unpacks a bundle archive (a top-level "ffmpeg/" directory) into dir.
func Extract(archive []byte, dir string) error { return Bundle.Extract(archive, dir) }

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
