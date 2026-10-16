//go:build windows

package takeout

import "io/fs"

// hardLinked: Windows file information does not carry the link count without opening the file with
// extra rights; the server folder is administrator-controlled, so hard links are not checked there.
func hardLinked(fs.FileInfo) bool { return false }
