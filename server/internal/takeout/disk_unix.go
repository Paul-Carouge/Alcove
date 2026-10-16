//go:build !windows

package takeout

import "golang.org/x/sys/unix"

// DiskSpace returns the bytes available to unprivileged users and the size of dir's file system.
func DiskSpace(dir string) (free, total uint64, err error) {
	var st unix.Statfs_t
	if err := unix.Statfs(dir, &st); err != nil {
		return 0, 0, err
	}
	bs := uint64(st.Bsize)                                     //nolint:gosec,unconvert // field types differ per OS
	return uint64(st.Bavail) * bs, uint64(st.Blocks) * bs, nil //nolint:unconvert // idem
}
