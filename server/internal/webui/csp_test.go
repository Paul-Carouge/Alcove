package webui

import "testing"

func TestScriptSrcFrom(t *testing.T) {
	cases := map[string]string{
		`<head><meta http-equiv="content-security-policy" content="script-src 'self' 'sha256-abc='"></head>`: "script-src 'self' 'sha256-abc='",
		`<meta http-equiv="content-security-policy" content="img-src 'self'; script-src 'self' 'sha256-x'">`: "script-src 'self' 'sha256-x'",
		`<html>no csp</html>`: DefaultScriptSrc,
	}
	for in, want := range cases {
		if got := scriptSrcFrom(in); got != want {
			t.Errorf("scriptSrcFrom(%q) = %q, want %q", in, got, want)
		}
	}
}
