package cli

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"github.com/spf13/cobra"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

func statusCmd() *cobra.Command {
	return &cobra.Command{
		Use:   "status",
		Short: "Show the installation, service state and available updates",
		RunE: func(*cobra.Command, []string) error {
			spec, mgr, err := installed()
			if err != nil {
				return err
			}
			fmt.Printf("%s %s\n", buildinfo.Name, buildinfo.Version)
			fmt.Printf("  service:  %s\n", mgr.Status())
			fmt.Printf("  mode:     %s (%s)\n", os.Getenv("ALCOVE_INSTALL_MODE"), os.Getenv("ALCOVE_SERVE_ARGS"))
			fmt.Printf("  data:     %s\n", spec.DataDir)
			fmt.Printf("  config:   %s\n", spec.EnvFile)
			ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
			defer cancel()
			if rel, _, err := latestRelease(ctx); err == nil {
				if updater.Newer(buildinfo.Version, rel.Version) {
					fmt.Printf("  update:   %s available, run \"alcove update\"\n", rel.Version)
				} else {
					fmt.Println("  update:   up to date")
				}
			}
			return nil
		},
	}
}

func uninstallCmd() *cobra.Command {
	var purge, yes bool
	cmd := &cobra.Command{
		Use:   "uninstall",
		Short: "Remove the service and binary (data is kept unless --purge)",
		RunE: func(*cobra.Command, []string) error {
			if runtime.GOOS == "linux" && !isRoot() {
				return errors.New("run with sudo")
			}
			u := newUI(yes)
			spec, mgr, err := installed()
			if err != nil {
				return err
			}
			if !u.confirm("Remove the "+buildinfo.Name+" service?", false) {
				return errAborted
			}
			if err := mgr.Uninstall(); err != nil {
				return err
			}
			for _, link := range []string{"/usr/local/bin/alcove", filepath.Join(os.Getenv("HOME"), ".local", "bin", "alcove")} {
				if target, err := os.Readlink(link); err == nil && target == spec.Binary {
					_ = os.Remove(link) // #nosec G703 -- only our own symlink, checked above
				}
			}
			_ = os.Remove(spec.Binary)
			_ = os.Remove(spec.Binary + ".old")
			if purge && u.confirm("Delete ALL data in "+spec.DataDir+" and the configuration? This cannot be undone.", false) {
				_ = os.Remove(spec.EnvFile)
				return os.RemoveAll(spec.DataDir) // #nosec G703 -- fixed install path, double confirmation
			}
			u.say("Service removed. Data kept in %s, configuration in %s.", spec.DataDir, spec.EnvFile)
			return nil
		},
	}
	cmd.Flags().BoolVar(&purge, "purge", false, "also delete data and configuration")
	cmd.Flags().BoolVarP(&yes, "yes", "y", false, "do not ask for confirmation")
	return cmd
}
