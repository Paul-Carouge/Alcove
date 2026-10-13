package ocr_test

import (
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/ocr"
)

func TestClean(t *testing.T) {
	for in, want := range map[string]string{
		"  a  b\r\n":               "a b",
		"x\n\n\n\n\ny":             "x\n\ny",
		"page 1\fpage 2":           "page 1\fpage 2",
		"bad\xffbyte\x00 \x07ok�!": "badbyte ok!",
	} {
		if got := ocr.Clean(in); got != want {
			t.Errorf("Clean(%q) = %q, want %q", in, got, want)
		}
	}
}
