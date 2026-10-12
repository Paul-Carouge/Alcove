package media

import "testing"

func TestParseFFmpegVersion(t *testing.T) {
	cases := []struct {
		out          string
		major, minor int
		ok           bool
	}{
		{"ffmpeg version 6.1.1-3ubuntu5 Copyright (c) 2000-2023", 6, 1, true},
		{"ffmpeg version 8.1 Copyright (c) 2000-2026", 8, 1, true},
		{"ffmpeg version n7.1.2 Copyright", 7, 1, true},
		{"ffmpeg version N-118000-g1234abcd Copyright", 0, 0, false},
		{"", 0, 0, false},
	}
	for _, c := range cases {
		major, minor, ok := parseFFmpegVersion(c.out)
		if major != c.major || minor != c.minor || ok != c.ok {
			t.Errorf("parseFFmpegVersion(%q) = %d.%d %v, want %d.%d %v", c.out, major, minor, ok, c.major, c.minor, c.ok)
		}
	}
}
