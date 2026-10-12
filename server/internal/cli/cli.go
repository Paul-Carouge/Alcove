// Package cli implements the administration commands of the alcove binary:
// install, update, rollback, status and uninstall (ADR 0014, ADR 0015).
// They run without bootstrapping PocketBase.
package cli

import (
	"bufio"
	"context"
	"crypto/rand"
	"encoding/base64"
	"errors"
	"fmt"
	"io"
	"net/http"
	"os"
	"runtime"
	"slices"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/envfile"
	"github.com/Paul-Carouge/Alcove/server/internal/service"
	"github.com/Paul-Carouge/Alcove/server/internal/updater"
)

// Commands handled here (everything else goes to PocketBase).
var Commands = []string{"install", "update", "rollback", "status", "uninstall"}

// Handles reports whether args[1] is one of Commands.
func Handles(args []string) bool {
	return len(args) > 1 && slices.Contains(Commands, args[1])
}

// Run executes an administration command and returns the exit code.
func Run(args []string) int {
	root := &cobra.Command{Use: "alcove", SilenceUsage: true, SilenceErrors: true}
	root.AddCommand(installCmd(), updateCmd(), rollbackCmd(), statusCmd(), uninstallCmd())
	root.SetArgs(args[1:])
	if err := root.Execute(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		return 1
	}
	return 0
}

// --- shared helpers ---

type ui struct {
	in  *bufio.Reader
	out io.Writer
	yes bool // non-interactive: accept defaults
}

func newUI(yes bool) *ui { return &ui{in: bufio.NewReader(os.Stdin), out: os.Stdout, yes: yes} }

func (u *ui) say(format string, a ...any) { _, _ = fmt.Fprintf(u.out, format+"\n", a...) }

func (u *ui) ask(question, def string) string {
	if u.yes {
		return def
	}
	if def != "" {
		_, _ = fmt.Fprintf(u.out, "%s [%s]: ", question, def)
	} else {
		_, _ = fmt.Fprintf(u.out, "%s: ", question)
	}
	line, _ := u.in.ReadString('\n')
	if line = strings.TrimSpace(line); line == "" {
		return def
	}
	return line
}

func (u *ui) confirm(question string, def bool) bool {
	d := "y/N"
	if def {
		d = "Y/n"
	}
	a := strings.ToLower(u.ask(question+" ("+d+")", ""))
	if a == "" {
		return def
	}
	return a == "y" || a == "yes" || a == "o" || a == "oui"
}

func isRoot() bool { return runtime.GOOS != "windows" && os.Geteuid() == 0 }

// systemWide: Linux and Windows installs are system-wide; macOS when run as root.
func systemWide() bool { return runtime.GOOS != "darwin" || isRoot() }

func randomSecret(n int) string {
	b := make([]byte, n)
	_, _ = rand.Read(b)
	return base64.RawURLEncoding.EncodeToString(b)
}

// installed loads the current installation (paths + configuration).
func installed() (service.Spec, service.Manager, error) {
	spec, err := service.Paths(systemWide())
	if err != nil {
		return spec, nil, err
	}
	if _, err := os.Stat(spec.EnvFile); err != nil {
		return spec, nil, fmt.Errorf("no installation found (%s is missing); run \"alcove install\" first", spec.EnvFile)
	}
	if err := envfile.Load(spec.EnvFile); err != nil {
		return spec, nil, err
	}
	mgr, err := service.For(spec.System)
	return spec, mgr, err
}

func releases() (*updater.Client, error) {
	api := os.Getenv("ALCOVE_UPDATE_URL")
	if api == "" {
		api = buildinfo.ReleasesAPI
	}
	return updater.New(api, buildinfo.Repo, buildinfo.ReleasePublicKey)
}

// waitHealthy polls the health URL until it answers 200 with the wanted
// version (any version if want is empty).
func waitHealthy(url, want string, timeout time.Duration) error {
	client := &http.Client{Timeout: 5 * time.Second}
	deadline := time.Now().Add(timeout)
	var last error
	for time.Now().Before(deadline) {
		res, err := client.Get(url) // #nosec G107 -- URL written by the installer
		if err == nil {
			body, _ := io.ReadAll(io.LimitReader(res.Body, 4096))
			_ = res.Body.Close()
			if res.StatusCode == http.StatusOK && (want == "" || strings.Contains(string(body), `"version":"`+want+`"`)) {
				return nil
			}
			last = fmt.Errorf("health answered %d: %s", res.StatusCode, body)
		} else {
			last = err
		}
		time.Sleep(time.Second)
	}
	return fmt.Errorf("server not healthy after %s: %w", timeout, last)
}

func healthURL() string {
	if u := os.Getenv("ALCOVE_HEALTH_URL"); u != "" {
		return u
	}
	return "http://127.0.0.1:8090/health"
}

func latestRelease(ctx context.Context) (*updater.Release, *updater.Client, error) {
	c, err := releases()
	if err != nil {
		return nil, nil, err
	}
	rel, err := c.Latest(ctx)
	if err != nil {
		return nil, nil, fmt.Errorf("cannot reach the release server: %w", err)
	}
	return rel, c, nil
}

var errAborted = errors.New("aborted")

// HelpStubs lists the administration commands in "alcove --help" (they are
// intercepted before PocketBase starts, so these never run).
func HelpStubs() []*cobra.Command {
	var out []*cobra.Command
	for _, c := range []*cobra.Command{installCmd(), updateCmd(), rollbackCmd(), statusCmd(), uninstallCmd()} {
		out = append(out, &cobra.Command{Use: c.Use, Short: c.Short, DisableFlagParsing: true, Run: func(*cobra.Command, []string) {}})
	}
	return out
}
