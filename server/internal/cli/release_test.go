package cli

import (
	"errors"
	"strings"
	"testing"
)

func TestReleaseErrorExplainsCommonCauses(t *testing.T) {
	for raw, hint := range map[string]string{
		`Get "https://api.github.com/x": tls: failed to verify certificate: x509: certificate signed by unknown authority`: "ca-certificates",
		`Get "https://api.github.com/x": dial tcp: lookup api.github.com: no such host`:                                    "internet connection",
		`HTTP 500`: "cannot reach the release server: HTTP 500",
	} {
		err := releaseError(errors.New(raw))
		if !strings.Contains(err.Error(), hint) {
			t.Errorf("%q → %q, want a hint containing %q", raw, err, hint)
		}
	}
}
