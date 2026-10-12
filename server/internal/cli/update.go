package cli

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/Paul-Carouge/Alcove/server/internal/backup"
	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/service"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

func updateCmd() *cobra.Command {
	var check, yes bool
	cmd := &cobra.Command{
		Use:   "update",
		Short: "Update " + buildinfo.Name + " to the latest release (backup first, automatic rollback)",
		RunE: func(*cobra.Command, []string) error {
			return update(check, yes)
		},
	}
	cmd.Flags().BoolVar(&check, "check", false, "only check whether an update is available")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "do not ask for confirmation")
	return cmd
}

func update(check, yes bool) error {
	u := newUI(yes)
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Minute)
	defer cancel()

	spec, mgr, err := installed()
	if os.Getenv("ALCOVE_INSTALL_MODE") == "docker" {
		return errors.New("this is a Docker installation: run deploy/update.sh next to docker-compose.yml")
	}
	rel, client, relErr := latestRelease(ctx)
	if relErr != nil {
		return relErr
	}
	if !updater.Newer(buildinfo.Version, rel.Version) {
		u.say("%s %s is up to date.", buildinfo.Name, buildinfo.Version)
		return nil
	}
	u.say("%s %s is available (installed: %s).\n%s", buildinfo.Name, rel.Version, buildinfo.Version, summary(rel.Notes))
	if check {
		return nil
	}
	if err != nil {
		return err
	}
	if runtime.GOOS == "linux" && !isRoot() {
		return errors.New("run the update with sudo")
	}
	if !u.confirm("Install "+rel.Version+" now?", true) {
		return errAborted
	}

	// 1. Download and verify before touching anything.
	tmp, err := os.MkdirTemp("", "alcove-update-")
	if err != nil {
		return err
	}
	defer func() { _ = os.RemoveAll(tmp) }()
	u.say("Downloading and verifying the signed release…")
	newExe, err := client.Download(ctx, rel, tmp)
	if err != nil {
		return err
	}

	// 2. Back up the database (online, consistent).
	u.say("Backing up the database…")
	if out, err := service.Runner(spec.Binary, "backup", "--dir="+spec.PBData(), "--label=pre-update-"+rel.Version); err != nil {
		return fmt.Errorf("backup failed, nothing was changed: %w\n%s", err, out)
	}
	if runtime.GOOS == "linux" {
		_, _ = service.Runner("chown", "-R", spec.User+":"+spec.User, filepath.Join(spec.PBData(), backup.Dir))
	}

	// 3. Swap the binary and restart.
	if err := updater.Replace(spec.Binary, newExe); err != nil {
		return err
	}
	if runtime.GOOS == "linux" {
		_, _ = service.Runner("chown", spec.User+":"+spec.User, spec.Binary)
	}
	u.say("Restarting…")
	if err := mgr.Restart(); err != nil {
		return rollbackAfter(u, spec, mgr, err)
	}
	if err := waitHealthy(healthURL(), rel.Version, 2*time.Minute); err != nil {
		return rollbackAfter(u, spec, mgr, err)
	}
	u.say("\n  ✓ %s %s is running. Release notes: %s", buildinfo.Name, rel.Version, rel.URL)
	return nil
}

func summary(notes string) string {
	lines := strings.Split(strings.TrimSpace(notes), "\n")
	if len(lines) > 12 {
		lines = append(lines[:12], "…")
	}
	return strings.Join(lines, "\n")
}

func rollbackAfter(u *ui, spec service.Spec, mgr service.Manager, cause error) error {
	u.say("The new version did not start (%v). Rolling back…", cause)
	if err := rollback(spec, mgr); err != nil {
		return fmt.Errorf("update failed (%w) and rollback failed: %w", cause, err)
	}
	return fmt.Errorf("update failed, previous version restored: %w", cause)
}

func rollbackCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "rollback",
		Short: "Restore the previous binary and the last pre-update database backup",
		RunE: func(*cobra.Command, []string) error {
			if runtime.GOOS == "linux" && !isRoot() {
				return errors.New("run with sudo")
			}
			spec, mgr, err := installed()
			if err != nil {
				return err
			}
			if err := rollback(spec, mgr); err != nil {
				return err
			}
			fmt.Println("Previous version restored.")
			return nil
		},
	}
}

func rollback(spec service.Spec, mgr service.Manager) error {
	old := spec.Binary + ".old"
	if _, err := os.Stat(old); err != nil {
		return errors.New("no previous binary to restore")
	}
	_ = mgr.Stop()
	if err := os.Rename(old, spec.Binary); err != nil {
		return err
	}
	files, err := backup.List(filepath.Join(spec.PBData(), backup.Dir))
	if err != nil {
		return err
	}
	for _, f := range files {
		if strings.Contains(filepath.Base(f), "-pre-update-") {
			if err := backup.Restore(spec.PBData(), f); err != nil {
				return err
			}
			if runtime.GOOS == "linux" {
				_, _ = service.Runner("chown", spec.User+":"+spec.User, filepath.Join(spec.PBData(), "data.db"))
			}
			break
		}
	}
	return mgr.Start()
}
