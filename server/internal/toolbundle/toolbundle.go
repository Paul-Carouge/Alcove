// Package toolbundle installs and activates the self-contained tool bundles that releases ship for
// native Linux installs: ffmpeg (ADR 0017) and the OCR tools (ADR 0025). Each lives next to the
// Alcove binary, in a directory named after the bundle, verified like the binary itself.
package toolbundle

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

const (
	sumFile = ".sha256"
	// maxFile bounds a single extracted file (libavcodec is ~16 MB, eng.traineddata ~23 MB).
	maxFile = 256 << 20
)

// Bundle describes one bundle: its name (the asset prefix and the directory) and the program that
// must be in every valid archive.
type Bundle struct {
	Name  string // "ffmpeg", "ocr"
	Probe string // e.g. "bin/ffmpeg"
}

// Supported reports whether releases ship bundles for this system.
func Supported() bool { return runtime.GOOS == "linux" }

// AssetName is the release asset for an architecture (amd64, arm64, armv7).
func (b Bundle) AssetName(arch string) string { return b.Name + "_linux_" + arch + ".tar.gz" }

// Dir is where the bundle lives for a given Alcove binary.
func (b Bundle) Dir(exe string) string { return filepath.Join(filepath.Dir(exe), b.Name) }

// Installed returns the checksum of the bundle installed in dir, or "" if there is none.
func Installed(dir string) string {
	data, err := os.ReadFile(filepath.Join(dir, sumFile)) // #nosec G304 -- our own install directory
	if err != nil {
		return ""
	}
	return strings.TrimSpace(string(data))
}

// Activate puts the bundle first on PATH when it is installed next to exe, so that every call of
// its programs by the process uses it. It reports whether it did.
func (b Bundle) Activate(exe string) bool {
	dir := b.Dir(exe)
	if Installed(dir) == "" {
		return false
	}
	bin := filepath.Join(dir, "bin")
	for _, p := range filepath.SplitList(os.Getenv("PATH")) {
		if p == bin {
			return true
		}
	}
	_ = os.Setenv("PATH", bin+string(os.PathListSeparator)+os.Getenv("PATH"))
	return true
}

// Install downloads the bundle of release r, verifies it against the signed checksums and installs
// it in dir, replacing an older one. It does nothing when the same bundle is already there.
func (b Bundle) Install(ctx context.Context, c *updater.Client, r *updater.Release, dir string) (changed bool, err error) {
	_, arch := updater.Platform()
	name := b.AssetName(arch)
	if r.Assets[name] == "" {
		return false, fmt.Errorf("v%s has no %s for linux/%s", r.Version, b.Name, arch)
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
	if err := b.Extract(archive, staged); err != nil {
		_ = os.RemoveAll(staged)
		return false, err
	}
	if err := os.WriteFile(filepath.Join(staged, sumFile), []byte(sums[name]+"\n"), 0o644); err != nil { // #nosec G306 -- not secret
		_ = os.RemoveAll(staged)
		return false, err
	}
	// Running processes keep their files open: swapping directories is safe.
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

// Extract unpacks a bundle archive (a top-level "<name>/" directory) into dir. Only regular files
// and directories inside it are accepted.
func (b Bundle) Extract(archive []byte, dir string) error {
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
		rel, ok := strings.CutPrefix(name, b.Name+"/")
		if name == b.Name {
			continue
		}
		if !ok || rel == "" || strings.HasPrefix(rel, "../") || path.IsAbs(rel) {
			return fmt.Errorf("unexpected path %q in %s archive", h.Name, b.Name)
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
			found = found || rel == b.Probe
		default:
			return fmt.Errorf("unexpected entry type for %q in %s archive", h.Name, b.Name)
		}
	}
	if !found {
		return fmt.Errorf("%s archive has no %s", b.Name, b.Probe)
	}
	return nil
}
