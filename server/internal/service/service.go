// Package service installs Alcove as a system service: systemd (Linux),
// launchd (macOS) or a startup scheduled task (Windows). See ADR 0014.
package service

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
)

// Name identifies the service on every platform.
const (
	Name         = "alcove"
	LaunchdLabel = "dev.alcove.server"
	WindowsTask  = "Alcove"
	LinuxUser    = "alcove"
	EnvInstalled = "ALCOVE_SERVICE" // set in the service environment
)

// Spec describes an installation.
type Spec struct {
	Binary  string   // installed executable (absolute)
	DataDir string   // root data directory; PocketBase data lives in DataDir/pb_data
	EnvFile string   // configuration written by the installer
	Args    []string // server arguments, e.g. ["serve", "--http=0.0.0.0:8090"]
	User    string   // Linux system user (empty elsewhere)
	System  bool     // system-wide (root) vs. per-user (macOS LaunchAgent)
}

// PBData returns the PocketBase data directory.
func (s Spec) PBData() string { return filepath.Join(s.DataDir, "pb_data") }

// Command returns the full service command line.
func (s Spec) Command() []string {
	cmd := append([]string{s.Binary}, s.Args...)
	return append(cmd, "--dir="+s.PBData(), "--env-file="+s.EnvFile)
}

// Paths returns the default layout for this OS (system or per-user).
func Paths(system bool) (Spec, error) {
	home, _ := os.UserHomeDir()
	switch runtime.GOOS {
	case "linux":
		if !system {
			return Spec{}, errors.New("run the installer with sudo on Linux")
		}
		return Spec{
			Binary: "/var/lib/alcove/bin/alcove", DataDir: "/var/lib/alcove",
			EnvFile: "/etc/alcove/alcove.env", User: LinuxUser, System: true,
		}, nil
	case "darwin":
		if system {
			return Spec{
				Binary: "/usr/local/lib/alcove/alcove", DataDir: "/usr/local/var/alcove",
				EnvFile: "/usr/local/etc/alcove/alcove.env", System: true,
			}, nil
		}
		base := filepath.Join(home, "Library", "Application Support", "Alcove")
		return Spec{Binary: filepath.Join(base, "bin", "alcove"), DataDir: base, EnvFile: filepath.Join(base, "alcove.env")}, nil
	case "windows":
		pf, pd := os.Getenv("ProgramFiles"), os.Getenv("ProgramData")
		if pf == "" || pd == "" {
			return Spec{}, errors.New("ProgramFiles/ProgramData not set")
		}
		return Spec{
			Binary: filepath.Join(pf, "Alcove", "alcove.exe"), DataDir: filepath.Join(pd, "Alcove"),
			EnvFile: filepath.Join(pd, "Alcove", "alcove.env"), System: true,
		}, nil
	}
	return Spec{}, fmt.Errorf("unsupported system %s", runtime.GOOS)
}

// --- definitions (pure, tested) ---

// SystemdUnit renders the hardened unit file. The binary lives in the data
// directory, owned by the service user, so self-updates can replace it while
// the rest of the system stays read-only.
func SystemdUnit(s Spec) string {
	return fmt.Sprintf(`[Unit]
Description=Alcove personal cloud
Documentation=https://github.com/Paul-Carouge/Alcove
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=%[1]s
Group=%[1]s
ExecStart=%[2]s
Environment=%[3]s=systemd
Restart=always
RestartSec=3
LimitNOFILE=65536
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
PrivateDevices=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
ReadWritePaths=%[4]s

[Install]
WantedBy=multi-user.target
`, s.User, quoteSystemd(s.Command()), EnvInstalled, s.DataDir)
}

func quoteSystemd(args []string) string {
	out := make([]string, len(args))
	for i, a := range args {
		if strings.ContainsAny(a, " \t\"\\") {
			a = `"` + strings.NewReplacer(`\`, `\\`, `"`, `\"`).Replace(a) + `"`
		}
		out[i] = a
	}
	return strings.Join(out, " ")
}

// LaunchdPlist renders the launchd job (KeepAlive restarts it after updates).
func LaunchdPlist(s Spec) string {
	var args strings.Builder
	for _, a := range s.Command() {
		fmt.Fprintf(&args, "\t\t<string>%s</string>\n", xmlEscape(a))
	}
	logs := filepath.Join(s.DataDir, "logs")
	return fmt.Sprintf(`<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>%s</string>
	<key>ProgramArguments</key>
	<array>
%s	</array>
	<key>EnvironmentVariables</key>
	<dict>
		<key>%s</key>
		<string>launchd</string>
	</dict>
	<key>RunAtLoad</key>
	<true/>
	<key>KeepAlive</key>
	<true/>
	<key>WorkingDirectory</key>
	<string>%s</string>
	<key>StandardOutPath</key>
	<string>%s</string>
	<key>StandardErrorPath</key>
	<string>%s</string>
</dict>
</plist>
`, LaunchdLabel, args.String(), EnvInstalled, xmlEscape(s.DataDir),
		xmlEscape(filepath.Join(logs, "alcove.log")), xmlEscape(filepath.Join(logs, "alcove.err.log")))
}

func xmlEscape(s string) string {
	return strings.NewReplacer("&", "&amp;", "<", "&lt;", ">", "&gt;", `"`, "&quot;").Replace(s)
}

// OpenRCScript renders the init script (Alpine and other OpenRC systems);
// supervise-daemon restarts the server when it exits (e.g. after an update).
func OpenRCScript(s Spec) string {
	cmd := s.Command()
	return fmt.Sprintf(`#!/sbin/openrc-run
name="Alcove"
description="Alcove personal cloud"
supervisor="supervise-daemon"
command=%q
command_args=%q
command_user="%[3]s:%[3]s"
directory=%q
capabilities="^cap_net_bind_service"
respawn_delay=3
respawn_max=0
output_log=%q
error_log=%q
export %s=openrc

depend() {
	need net
	after firewall
}
`, cmd[0], strings.Join(cmd[1:], " "), s.User, s.DataDir,
		filepath.Join(s.DataDir, "logs", "alcove.log"), filepath.Join(s.DataDir, "logs", "alcove.err.log"), EnvInstalled)
}

// WindowsTaskCommand is the command line of the startup task.
func WindowsTaskCommand(s Spec) string {
	parts := s.Command()
	for i, p := range parts {
		if strings.ContainsAny(p, " \t") {
			parts[i] = `"` + p + `"`
		}
	}
	return strings.Join(parts, " ")
}

// --- managers ---

// Manager controls the installed service.
type Manager interface {
	Install(Spec) error
	Uninstall() error
	Start() error
	Stop() error
	Restart() error
	// Status returns a short human-readable state ("running", "stopped", "not installed").
	Status() string
}

// Runner executes commands (replaced in tests).
var Runner = func(name string, args ...string) (string, error) {
	out, err := exec.Command(name, args...).CombinedOutput() // #nosec G204 -- fixed service tools
	return strings.TrimSpace(string(out)), err
}

// For returns the manager for this OS.
func For(system bool) (Manager, error) {
	switch runtime.GOOS {
	case "linux":
		if _, err := exec.LookPath("systemctl"); err == nil && isDir("/run/systemd/system") {
			return systemd{}, nil
		}
		if _, err := exec.LookPath("rc-service"); err == nil {
			return openrc{}, nil
		}
		return nil, errors.New("no supported service manager (systemd or OpenRC) was found: start Alcove yourself with the printed command, or use Docker")
	case "darwin":
		return launchd{system: system}, nil
	case "windows":
		return windowsTask{}, nil
	}
	return nil, fmt.Errorf("unsupported system %s", runtime.GOOS)
}

type systemd struct{}

const unitPath = "/etc/systemd/system/alcove.service"

func (systemd) Install(s Spec) error {
	if err := os.WriteFile(unitPath, []byte(SystemdUnit(s)), 0o644); err != nil { // #nosec G306 -- unit files are world-readable
		return err
	}
	if out, err := Runner("systemctl", "daemon-reload"); err != nil {
		return fmt.Errorf("systemctl daemon-reload: %w: %s", err, out)
	}
	if out, err := Runner("systemctl", "enable", "--now", Name); err != nil {
		return fmt.Errorf("systemctl enable: %w: %s", err, out)
	}
	return nil
}

func (systemd) Uninstall() error {
	_, _ = Runner("systemctl", "disable", "--now", Name)
	if err := os.Remove(unitPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	_, _ = Runner("systemctl", "daemon-reload")
	return nil
}

func (systemd) Start() error   { return run("systemctl", "start", Name) }
func (systemd) Stop() error    { return run("systemctl", "stop", Name) }
func (systemd) Restart() error { return run("systemctl", "restart", Name) }
func (systemd) Status() string {
	if _, err := os.Stat(unitPath); err != nil {
		return "not installed"
	}
	out, _ := Runner("systemctl", "is-active", Name)
	if out == "active" {
		return "running"
	}
	return out
}

func isDir(p string) bool {
	info, err := os.Stat(p)
	return err == nil && info.IsDir()
}

type openrc struct{}

const openrcPath = "/etc/init.d/alcove"

func (openrc) Install(s Spec) error {
	if err := os.MkdirAll(filepath.Join(s.DataDir, "logs"), 0o750); err != nil {
		return err
	}
	_, _ = Runner("chown", s.User+":"+s.User, filepath.Join(s.DataDir, "logs"))
	if err := os.WriteFile(openrcPath, []byte(OpenRCScript(s)), 0o755); err != nil { // #nosec G306 -- init scripts are executable
		return err
	}
	if err := run("rc-update", "add", Name, "default"); err != nil {
		return err
	}
	return run("rc-service", Name, "restart")
}

func (openrc) Uninstall() error {
	_, _ = Runner("rc-service", Name, "stop")
	_, _ = Runner("rc-update", "del", Name, "default")
	if err := os.Remove(openrcPath); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

func (openrc) Start() error   { return run("rc-service", Name, "start") }
func (openrc) Stop() error    { return run("rc-service", Name, "stop") }
func (openrc) Restart() error { return run("rc-service", Name, "restart") }
func (openrc) Status() string {
	if _, err := os.Stat(openrcPath); err != nil {
		return "not installed"
	}
	out, _ := Runner("rc-service", Name, "status")
	if strings.Contains(out, "started") {
		return "running"
	}
	return "stopped"
}

type launchd struct{ system bool }

func (l launchd) plistPath() string {
	if l.system {
		return "/Library/LaunchDaemons/" + LaunchdLabel + ".plist"
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, "Library", "LaunchAgents", LaunchdLabel+".plist")
}

func (l launchd) target() string {
	if l.system {
		return "system/" + LaunchdLabel
	}
	return fmt.Sprintf("gui/%d/%s", os.Getuid(), LaunchdLabel)
}

func (l launchd) domain() string {
	if l.system {
		return "system"
	}
	return fmt.Sprintf("gui/%d", os.Getuid())
}

func (l launchd) Install(s Spec) error {
	if err := os.MkdirAll(filepath.Join(s.DataDir, "logs"), 0o750); err != nil {
		return err
	}
	if err := os.MkdirAll(filepath.Dir(l.plistPath()), 0o755); err != nil { // #nosec G301 -- standard LaunchAgents/LaunchDaemons folder
		return err
	}
	if err := os.WriteFile(l.plistPath(), []byte(LaunchdPlist(s)), 0o644); err != nil { // #nosec G306 -- plist files are world-readable
		return err
	}
	_, _ = Runner("launchctl", "bootout", l.target())
	return run("launchctl", "bootstrap", l.domain(), l.plistPath())
}

func (l launchd) Uninstall() error {
	_, _ = Runner("launchctl", "bootout", l.target())
	if err := os.Remove(l.plistPath()); err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return nil
}

func (l launchd) Start() error   { return run("launchctl", "kickstart", l.target()) }
func (l launchd) Stop() error    { return run("launchctl", "kill", "SIGTERM", l.target()) }
func (l launchd) Restart() error { return run("launchctl", "kickstart", "-k", l.target()) }
func (l launchd) Status() string {
	if _, err := os.Stat(l.plistPath()); err != nil {
		return "not installed"
	}
	out, err := Runner("launchctl", "print", l.target())
	if err != nil {
		return "stopped"
	}
	if strings.Contains(out, "state = running") {
		return "running"
	}
	return "stopped"
}

type windowsTask struct{}

func (windowsTask) Install(s Spec) error {
	if err := run("schtasks", "/Create", "/F", "/TN", WindowsTask, "/SC", "ONSTART", "/RU", "SYSTEM",
		"/RL", "HIGHEST", "/TR", WindowsTaskCommand(s)); err != nil {
		return err
	}
	return run("schtasks", "/Run", "/TN", WindowsTask)
}

func (windowsTask) Uninstall() error {
	_, _ = Runner("schtasks", "/End", "/TN", WindowsTask)
	_, _ = Runner("schtasks", "/Delete", "/F", "/TN", WindowsTask)
	return nil
}

func (windowsTask) Start() error { return run("schtasks", "/Run", "/TN", WindowsTask) }
func (windowsTask) Stop() error  { return run("schtasks", "/End", "/TN", WindowsTask) }
func (w windowsTask) Restart() error {
	_ = w.Stop()
	return w.Start()
}
func (windowsTask) Status() string {
	out, err := Runner("schtasks", "/Query", "/TN", WindowsTask, "/FO", "LIST")
	switch {
	case err != nil:
		return "not installed"
	case strings.Contains(out, "Running"):
		return "running"
	default:
		return "stopped"
	}
}

func run(name string, args ...string) error {
	if out, err := Runner(name, args...); err != nil {
		return fmt.Errorf("%s %s: %w: %s", name, strings.Join(args, " "), err, out)
	}
	return nil
}
