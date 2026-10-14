package cli

import (
	"context"
	"fmt"
	"runtime"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/ffbundle"
	"github.com/Paul-Carouge/Alcove/server/internal/service"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

// releaseForThisVersion returns the release of the running binary, or the latest one for
// development builds.
func releaseForThisVersion(ctx context.Context) (*updater.Client, *updater.Release, error) {
	c, err := releases()
	if err != nil {
		return nil, nil, err
	}
	if rel, err := c.Release(ctx, buildinfo.Version); err == nil {
		return c, rel, nil
	}
	rel, err := c.Latest(ctx)
	if err != nil {
		return nil, nil, releaseError(err)
	}
	return c, rel, nil
}

// syncFFmpeg installs or refreshes Alcove's own ffmpeg (Linux) from rel. It asks first unless the
// bundle is already in use; nothing happens when the system ffmpeg is recent enough. The service
// must be restarted to use a changed bundle.
func syncFFmpeg(ctx context.Context, u *ui, spec service.Spec, c *updater.Client, rel *updater.Release) (changed bool, err error) {
	dir := ffbundle.Dir(spec.Binary)
	if ffbundle.Installed(dir) == "" {
		sys := ffbundle.System()
		if sys.Recent() {
			u.say("  ✓ ffmpeg %s found", sys)
			return false, nil
		}
		why := "is not installed"
		if sys.Found {
			why = fmt.Sprintf("%s is too old for phone photos (HEIC needs 7.1 or newer)", sys)
		}
		if !u.confirm(fmt.Sprintf("ffmpeg %s. Install %s's own copy (about 45 MB in %s; the system is not changed)?", why, buildinfo.Name, dir), true) {
			return false, nil
		}
	}
	u.say("Downloading and verifying ffmpeg…")
	changed, err = ffbundle.Install(ctx, c, rel, dir)
	if err != nil {
		return false, err
	}
	if runtime.GOOS == "linux" && spec.User != "" {
		_, _ = service.Runner("chown", "-R", spec.User+":"+spec.User, dir)
	}
	if changed {
		u.say("  ✓ ffmpeg installed in %s", dir)
	} else {
		u.say("  ✓ ffmpeg is up to date")
	}
	return changed, nil
}
