//go:build !windows

package takeout

import (
	"io/fs"
	"syscall"
)

// hardLinked reports a file with several names: os.Root cannot tell where a hard link points.
func hardLinked(info fs.FileInfo) bool {
	st, ok := info.Sys().(*syscall.Stat_t)
	return ok && st.Nlink > 1
}
