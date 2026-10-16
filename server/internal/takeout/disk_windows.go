//go:build windows

package takeout

import "golang.org/x/sys/windows"

// DiskSpace returns the bytes available to the caller and the size of the volume holding dir.
func DiskSpace(dir string) (free, total uint64, err error) {
	p, err := windows.UTF16PtrFromString(dir)
	if err != nil {
		return 0, 0, err
	}
	if err := windows.GetDiskFreeSpaceEx(p, &free, &total, nil); err != nil {
		return 0, 0, err
	}
	return free, total, nil
}
