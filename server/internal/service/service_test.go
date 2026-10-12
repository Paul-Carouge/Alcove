package service_test

import (
	"encoding/xml"
	"strings"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/service"
)

var spec = service.Spec{
	Binary: "/var/lib/alcove/bin/alcove", DataDir: "/var/lib/alcove", EnvFile: "/etc/alcove/alcove.env",
	Args: []string{"serve", "cloud.example.com"}, User: "alcove", System: true,
}

func TestSystemdUnit(t *testing.T) {
	u := service.SystemdUnit(spec)
	for _, want := range []string{
		"ExecStart=/var/lib/alcove/bin/alcove serve cloud.example.com --dir=/var/lib/alcove/pb_data --env-file=/etc/alcove/alcove.env",
		"User=alcove", "Restart=always", "AmbientCapabilities=CAP_NET_BIND_SERVICE",
		"ProtectSystem=strict", "ReadWritePaths=/var/lib/alcove", "Environment=ALCOVE_SERVICE=systemd", "NoNewPrivileges=true",
	} {
		if !strings.Contains(u, want) {
			t.Errorf("unit misses %q", want)
		}
	}
}

func TestSystemdQuotesSpaces(t *testing.T) {
	s := spec
	s.DataDir = "/srv/my data"
	if !strings.Contains(service.SystemdUnit(s), `"--dir=/srv/my data/pb_data"`) {
		t.Error("paths with spaces must be quoted")
	}
}

func TestLaunchdPlistIsValidXML(t *testing.T) {
	s := spec
	s.DataDir = "/Users/me/Library/Application Support/Alcove & co"
	p := service.LaunchdPlist(s)
	if err := xml.Unmarshal([]byte(p), new(any)); err != nil {
		t.Fatalf("invalid plist XML: %v", err)
	}
	for _, want := range []string{"<key>KeepAlive</key>", service.LaunchdLabel, "&amp; co", "<string>launchd</string>"} {
		if !strings.Contains(p, want) {
			t.Errorf("plist misses %q", want)
		}
	}
}

func TestWindowsTaskQuotesPaths(t *testing.T) {
	s := service.Spec{Binary: `C:\Program Files\Alcove\alcove.exe`, DataDir: `C:\ProgramData\Alcove`, EnvFile: `C:\ProgramData\Alcove\alcove.env`, Args: []string{"serve"}}
	if got := service.WindowsTaskCommand(s); !strings.HasPrefix(got, `"C:\Program Files\Alcove\alcove.exe" serve`) {
		t.Errorf("command = %s", got)
	}
}

func TestOpenRCScript(t *testing.T) {
	sc := service.OpenRCScript(spec)
	for _, want := range []string{
		"#!/sbin/openrc-run", `command="/var/lib/alcove/bin/alcove"`,
		`command_args="serve cloud.example.com --dir=/var/lib/alcove/pb_data --env-file=/etc/alcove/alcove.env"`,
		`command_user="alcove:alcove"`, `supervisor="supervise-daemon"`, "cap_net_bind_service", "export ALCOVE_SERVICE=openrc",
	} {
		if !strings.Contains(sc, want) {
			t.Errorf("script misses %q", want)
		}
	}
}
