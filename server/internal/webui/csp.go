package webui

import (
	"io/fs"
	"regexp"
	"strings"
)

// DefaultScriptSrc is used when the web UI is not embedded.
const DefaultScriptSrc = "script-src 'self'"

var metaCSP = regexp.MustCompile(`<meta http-equiv="content-security-policy" content="([^"]*)"`)

// scriptSrcFrom extracts the script-src directive (with SvelteKit's inline
// script hashes) from a built index.html.
func scriptSrcFrom(indexHTML string) string {
	m := metaCSP.FindStringSubmatch(indexHTML)
	if m == nil {
		return DefaultScriptSrc
	}
	for d := range strings.SplitSeq(m[1], ";") {
		d = strings.TrimSpace(d)
		if strings.HasPrefix(d, "script-src ") {
			return d
		}
	}
	return DefaultScriptSrc
}

// ScriptSrc returns the script-src directive the embedded web UI needs. The
// server must include it in its CSP header: when a page has both a header and
// a <meta> CSP, the browser enforces both.
func ScriptSrc() string {
	sub, err := fs.Sub(dist, "dist")
	if err != nil {
		return DefaultScriptSrc
	}
	b, err := fs.ReadFile(sub, "index.html")
	if err != nil {
		return DefaultScriptSrc
	}
	return scriptSrcFrom(string(b))
}
