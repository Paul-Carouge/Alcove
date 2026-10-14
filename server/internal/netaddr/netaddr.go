// Package netaddr finds the addresses a phone or another computer can use to reach this machine.
package netaddr

import (
	"net"
	"net/url"
	"sort"
)

// LAN returns this machine's private IPv4 addresses (home network, Tailscale), most likely first:
// 192.168.x before 10.x before 172.16-31.x before 100.64/10.
func LAN() []string {
	ifaces, err := net.Interfaces()
	if err != nil {
		return nil
	}
	var out []string
	for _, ifc := range ifaces {
		if ifc.Flags&net.FlagUp == 0 || ifc.Flags&net.FlagLoopback != 0 {
			continue
		}
		addrs, _ := ifc.Addrs()
		for _, a := range addrs {
			ipn, ok := a.(*net.IPNet)
			if !ok {
				continue
			}
			if ip := ipn.IP.To4(); ip != nil && usable(ip) {
				out = append(out, ip.String())
			}
		}
	}
	sort.SliceStable(out, func(i, j int) bool { return rank(out[i]) < rank(out[j]) })
	return out
}

var cgnat = &net.IPNet{IP: net.IPv4(100, 64, 0, 0), Mask: net.CIDRMask(10, 32)}

func usable(ip net.IP) bool { return ip.IsPrivate() || cgnat.Contains(ip) }

func rank(s string) int {
	switch net.ParseIP(s).To4()[0] {
	case 192:
		return 0
	case 10:
		return 1
	case 172:
		return 2
	}
	return 3
}

// Reachable rewrites a listen URL bound to every interface (0.0.0.0, ::) into URLs others can open,
// one per LAN address; other URLs are returned as they are.
func Reachable(listen string) []string {
	u, err := url.Parse(listen)
	if err != nil {
		return []string{listen}
	}
	host := u.Hostname()
	if host != "0.0.0.0" && host != "::" && host != "" {
		return []string{listen}
	}
	port := u.Port()
	var out []string
	for _, ip := range LAN() {
		v := *u
		v.Host = net.JoinHostPort(ip, port)
		out = append(out, v.String())
	}
	if len(out) == 0 {
		v := *u
		v.Host = net.JoinHostPort("127.0.0.1", port)
		out = append(out, v.String())
	}
	return out
}
