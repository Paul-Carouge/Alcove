package netaddr

import (
	"net"
	"strings"
	"testing"
)

func TestReachable(t *testing.T) {
	if got := Reachable("https://cloud.example.com"); len(got) != 1 || got[0] != "https://cloud.example.com" {
		t.Errorf("public URL changed: %v", got)
	}
	for _, u := range Reachable("http://0.0.0.0:8090") {
		if strings.Contains(u, "0.0.0.0") || !strings.HasSuffix(u, ":8090") {
			t.Errorf("unusable address %q", u)
		}
	}
}

func TestOnlyPrivateAddresses(t *testing.T) {
	for ip, want := range map[string]bool{
		"192.168.1.20": true, "10.0.0.3": true, "172.20.1.1": true, "100.101.102.103": true,
		"8.8.8.8": false, "127.0.0.1": false, "169.254.1.1": false,
	} {
		if got := usable(net.ParseIP(ip).To4()); got != want {
			t.Errorf("%s: %v", ip, got)
		}
	}
	if rank("192.168.1.2") > rank("10.0.0.1") {
		t.Error("home network addresses come first")
	}
}
