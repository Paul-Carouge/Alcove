package cli

import (
	"errors"
	"fmt"
	"io"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/spf13/cobra"

	"github.com/Paul-Carouge/Alcove/server/internal/buildinfo"
	"github.com/Paul-Carouge/Alcove/server/internal/envfile"
	"github.com/Paul-Carouge/Alcove/server/internal/service"
)

type installOpts struct {
	mode     string // public | local | proxy
	domain   string
	port     int
	yes      bool
	noFFmpeg bool
	noStart  bool
}

func installCmd() *cobra.Command {
	var o installOpts
	cmd := &cobra.Command{
		Use:   "install",
		Short: "Install " + buildinfo.Name + " as a system service (asks a few questions)",
		RunE:  func(*cobra.Command, []string) error { return install(o) },
	}
	f := cmd.Flags()
	f.StringVar(&o.mode, "mode", "", "public (domain + automatic HTTPS), local (LAN/Tailscale) or proxy (behind your reverse proxy)")
	f.StringVar(&o.domain, "domain", "", "public domain name (mode public)")
	f.IntVar(&o.port, "port", 8090, "HTTP port (modes local and proxy)")
	f.BoolVarP(&o.yes, "yes", "y", false, "accept defaults, no questions")
	f.BoolVar(&o.noFFmpeg, "no-ffmpeg", false, "do not install ffmpeg")
	f.BoolVar(&o.noStart, "no-start", false, "write files but do not register/start the service")
	return cmd
}

func install(o installOpts) error {
	u := newUI(o.yes)
	if runtime.GOOS == "linux" && !isRoot() {
		return errors.New("run the installer with sudo")
	}
	spec, err := service.Paths(systemWide())
	if err != nil {
		return err
	}
	u.say("\n  %s %s installer\n", buildinfo.Name, buildinfo.Version)

	// 1. Access mode.
	if o.mode == "" {
		u.say("How will you reach %s?", buildinfo.Name)
		u.say("  1) From the internet, with a domain name (automatic HTTPS; ports 80 and 443 must be open)")
		u.say("  2) On my local network or Tailscale (http://<this machine>:%d)", o.port)
		u.say("  3) Behind my own reverse proxy (listens on 127.0.0.1:%d)", o.port)
		switch u.ask("Choice", "2") {
		case "1":
			o.mode = "public"
		case "3":
			o.mode = "proxy"
		default:
			o.mode = "local"
		}
	}
	if o.mode == "public" && o.domain == "" {
		o.domain = u.ask("Domain name (its DNS must point to this machine)", "")
	}
	if err := validate(o); err != nil {
		return err
	}

	// 2. Configuration (kept across reinstalls: secrets must not change).
	vars := map[string]string{}
	if _, err := os.Stat(spec.EnvFile); err == nil {
		if err := envfile.Load(spec.EnvFile); err != nil {
			return err
		}
		for _, k := range []string{"ALCOVE_SECRET_KEY", "ALCOVE_SETUP_TOKEN"} {
			vars[k] = os.Getenv(k)
		}
	}
	if vars["ALCOVE_SECRET_KEY"] == "" {
		vars["ALCOVE_SECRET_KEY"] = randomSecret(32)
	}
	if vars["ALCOVE_SETUP_TOKEN"] == "" {
		vars["ALCOVE_SETUP_TOKEN"] = randomSecret(24)
	}
	base := ""
	switch o.mode {
	case "public":
		spec.Args = []string{"serve", o.domain}
		vars["ALCOVE_DOMAIN"] = o.domain
		base = "https://" + o.domain
		vars["ALCOVE_HEALTH_URL"] = base + "/health"
	case "proxy":
		spec.Args = []string{"serve", "--http=127.0.0.1:" + strconv.Itoa(o.port)}
		vars["ALCOVE_TRUSTED_PROXY_HEADER"] = "X-Forwarded-For"
		base = "http://127.0.0.1:" + strconv.Itoa(o.port)
		vars["ALCOVE_HEALTH_URL"] = base + "/health"
	default:
		spec.Args = []string{"serve", "--http=0.0.0.0:" + strconv.Itoa(o.port)}
		base = "http://" + hostname() + ":" + strconv.Itoa(o.port)
		vars["ALCOVE_HEALTH_URL"] = "http://127.0.0.1:" + strconv.Itoa(o.port) + "/health"
	}
	vars["ALCOVE_INSTALL_MODE"] = "native"
	vars["ALCOVE_SERVE_ARGS"] = strings.Join(spec.Args, " ")

	// 3. Files: binary, data, configuration.
	for _, dir := range []string{filepath.Dir(spec.Binary), spec.PBData(), filepath.Dir(spec.EnvFile)} {
		if err := os.MkdirAll(dir, 0o750); err != nil {
			return err
		}
	}
	self, err := os.Executable()
	if err != nil {
		return err
	}
	if self, err = filepath.EvalSymlinks(self); err != nil {
		return err
	}
	if self != spec.Binary {
		if err := copyExecutable(self, spec.Binary); err != nil {
			return fmt.Errorf("install binary: %w", err)
		}
	}
	if err := linkOnPath(spec.Binary); err != nil {
		u.say("  ! could not add %s to the PATH: %v", spec.Binary, err)
	}
	order := []string{"ALCOVE_INSTALL_MODE", "ALCOVE_SERVE_ARGS", "ALCOVE_DOMAIN", "ALCOVE_TRUSTED_PROXY_HEADER",
		"ALCOVE_HEALTH_URL", "ALCOVE_SECRET_KEY", "ALCOVE_SETUP_TOKEN"}
	var kv [][2]string
	for _, k := range order {
		if v := vars[k]; v != "" {
			kv = append(kv, [2]string{k, v})
		}
	}
	header := fmt.Sprintf("%s configuration, written by \"alcove install\" on %s.\nALCOVE_SECRET_KEY encrypts two-factor secrets: back this file up and never lose it.",
		buildinfo.Name, time.Now().Format("2006-01-02"))
	if err := envfile.Write(spec.EnvFile, header, kv); err != nil {
		return err
	}
	if runtime.GOOS == "linux" {
		if err := ensureLinuxUser(spec); err != nil {
			return err
		}
	}

	// 4. ffmpeg (photos and videos).
	if !o.noFFmpeg {
		ensureFFmpeg(u)
	}

	if o.noStart {
		u.say("\nFiles are in place. Start the server with:\n  %s", strings.Join(spec.Command(), " "))
		return nil
	}

	// 5. Service.
	mgr, err := service.For(spec.System)
	if err != nil {
		u.say("\n%v\nStart it with:\n  %s", err, strings.Join(spec.Command(), " "))
		return nil
	}
	u.say("Starting the %s service…", buildinfo.Name)
	if err := mgr.Install(spec); err != nil {
		return err
	}
	if err := waitHealthy(vars["ALCOVE_HEALTH_URL"], "", 90*time.Second); err != nil {
		return fmt.Errorf("the service was installed but does not answer yet: %w", err)
	}
	u.say("\n  ✓ %s is running.\n\n  Finish the setup in your browser:\n    %s/setup?token=%s\n",
		buildinfo.Name, base, url.QueryEscape(vars["ALCOVE_SETUP_TOKEN"]))
	u.say("  Update later with:  sudo alcove update\n  Status:             alcove status\n")
	return nil
}

func validate(o installOpts) error {
	switch o.mode {
	case "public":
		if o.domain == "" || strings.ContainsAny(o.domain, "/: ") || !strings.Contains(o.domain, ".") {
			return fmt.Errorf("invalid domain %q", o.domain)
		}
	case "local", "proxy":
		if o.port < 1 || o.port > 65535 {
			return fmt.Errorf("invalid port %d", o.port)
		}
	default:
		return fmt.Errorf("unknown mode %q (public, local or proxy)", o.mode)
	}
	return nil
}

func hostname() string {
	h, err := os.Hostname()
	if err != nil || h == "" {
		return "localhost"
	}
	if runtime.GOOS == "darwin" && !strings.Contains(h, ".") {
		return h + ".local"
	}
	return h
}

func copyExecutable(src, dst string) error {
	in, err := os.Open(src) // #nosec G304 -- the running executable
	if err != nil {
		return err
	}
	defer func() { _ = in.Close() }()
	tmp := dst + ".tmp"
	out, err := os.OpenFile(tmp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o755) // #nosec G302 G304 -- installed executable
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		_ = out.Close()
		return err
	}
	if err := out.Close(); err != nil {
		return err
	}
	return os.Rename(tmp, dst)
}

// linkOnPath makes "alcove" available in the PATH.
func linkOnPath(binary string) error {
	var link string
	switch runtime.GOOS {
	case "linux", "darwin":
		if !isRoot() {
			home, _ := os.UserHomeDir()
			link = filepath.Join(home, ".local", "bin", "alcove")
		} else {
			link = "/usr/local/bin/alcove"
		}
	default:
		return nil // Windows: the installer script adds the folder to PATH
	}
	if err := os.MkdirAll(filepath.Dir(link), 0o755); err != nil { // #nosec G301 -- standard bin folder
		return err
	}
	_ = os.Remove(link)
	return os.Symlink(binary, link)
}

func ensureLinuxUser(spec service.Spec) error {
	if _, err := exec.Command("id", "-u", spec.User).Output(); err != nil { // #nosec G204 -- fixed user name
		nologin := "/usr/sbin/nologin"
		if _, err := os.Stat(nologin); err != nil {
			nologin = "/sbin/nologin"
		}
		if out, err := service.Runner("useradd", "--system", "--user-group", "--home-dir", spec.DataDir, "--shell", nologin, spec.User); err != nil {
			// BusyBox (Alpine): create the group first, or the user lands in "nogroup".
			_, _ = service.Runner("addgroup", "-S", spec.User)
			if out2, err2 := service.Runner("adduser", "-S", "-D", "-H", "-h", spec.DataDir, "-s", nologin, "-G", spec.User, spec.User); err2 != nil {
				return fmt.Errorf("create user %s: %w (%s) / %w (%s)", spec.User, err, out, err2, out2)
			}
		}
	}
	// The service user owns its data and its binary (self-updates); the
	// configuration stays root-owned but readable by the group.
	if out, err := service.Runner("chown", "-R", spec.User+":"+spec.User, spec.DataDir); err != nil {
		return fmt.Errorf("chown %s: %w: %s", spec.DataDir, err, out)
	}
	for _, p := range []string{filepath.Dir(spec.EnvFile), spec.EnvFile} {
		if out, err := service.Runner("chown", "root:"+spec.User, p); err != nil {
			return fmt.Errorf("chown %s: %w: %s", p, err, out)
		}
	}
	if err := os.Chmod(filepath.Dir(spec.EnvFile), 0o750); err != nil { // #nosec G302 -- service group may traverse
		return err
	}
	return os.Chmod(spec.EnvFile, 0o640) // #nosec G302 -- readable by the service group, not others
}

// ensureFFmpeg offers to install ffmpeg with the system package manager.
func ensureFFmpeg(u *ui) {
	if _, err := exec.LookPath("ffmpeg"); err == nil {
		u.say("  ✓ ffmpeg found")
		return
	}
	cmd := ffmpegInstallCommand()
	if cmd == nil {
		u.say("  ! ffmpeg not found: install it for video and HEIC thumbnails (optional)")
		return
	}
	if !u.confirm("ffmpeg (video and HEIC thumbnails) is not installed. Install it now with "+cmd[0]+"?", true) {
		return
	}
	if out, err := service.Runner(cmd[0], cmd[1:]...); err != nil {
		u.say("  ! ffmpeg installation failed (%v); you can install it later.\n%s", err, lastLines(out, 5))
		return
	}
	u.say("  ✓ ffmpeg installed")
}

func ffmpegInstallCommand() []string {
	candidates := [][]string{
		{"apt-get", "install", "-y", "ffmpeg"},
		{"dnf", "install", "-y", "ffmpeg"},
		{"yum", "install", "-y", "ffmpeg"},
		{"apk", "add", "--no-cache", "ffmpeg"},
		{"pacman", "-S", "--noconfirm", "ffmpeg"},
		{"zypper", "--non-interactive", "install", "ffmpeg"},
		{"winget", "install", "--silent", "--accept-package-agreements", "--accept-source-agreements", "Gyan.FFmpeg"},
	}
	if runtime.GOOS == "darwin" && !isRoot() {
		candidates = append([][]string{{"brew", "install", "ffmpeg"}}, candidates...)
	}
	for _, c := range candidates {
		if _, err := exec.LookPath(c[0]); err == nil {
			return c
		}
	}
	return nil
}

func lastLines(s string, n int) string {
	lines := strings.Split(strings.TrimSpace(s), "\n")
	return strings.Join(lines[max(0, len(lines)-n):], "\n")
}
