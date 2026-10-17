package takeout

import (
	"encoding/binary"
	"io"
	"sync/atomic"
)

// budgetReaderAt bounds what archive/zip may read while it parses an archive's directory. zip.NewReader
// allocates one File per central directory header it reads, wherever its end records make it start, so
// a small archive of millions of empty entries would exhaust memory before any entry limit could apply.
// Bounding the bytes it reads bounds the headers, whatever the end records say. Once the directory is
// parsed, the budget is lifted: the same reader then serves the entries' data.
type budgetReaderAt struct {
	r        io.ReaderAt
	left     atomic.Int64
	limited  atomic.Bool
	exceeded atomic.Bool // archive/zip may turn the error into a short read and keep a partial list
}

func newBudgetReaderAt(r io.ReaderAt, budget int64) *budgetReaderAt {
	b := &budgetReaderAt{r: r}
	b.left.Store(budget)
	b.limited.Store(true)
	return b
}

func (b *budgetReaderAt) ReadAt(p []byte, off int64) (int, error) {
	if b.limited.Load() && b.left.Add(-int64(len(p))) < 0 {
		b.exceeded.Store(true)
		return 0, errUnsafe
	}
	return b.r.ReadAt(p, off)
}

// lift removes the limit.
func (b *budgetReaderAt) lift() { b.limited.Store(false) }

// declaredRecords reads the entry count an archive's end records declare, exactly where archive/zip's
// readDirectoryEnd reads it (Go 1.27): zip.NewReader preallocates that many entries before reading the
// directory whenever the archive is large enough to hold them, so a 40 GB archive ending in a crafted
// ZIP64 record would make it allocate gigabytes after reading a kilobyte.
func declaredRecords(r io.ReaderAt, size int64) (uint64, error) {
	const eocdLen, locLen, eocd64Len = 22, 20, 56
	le := binary.LittleEndian
	var buf []byte
	var eocdPos int64 = -1
	for i, n := range []int64{1024, 65 * 1024} {
		n = min(n, size)
		buf = make([]byte, n)
		if _, err := r.ReadAt(buf, size-n); err != nil && err != io.EOF {
			return 0, err
		}
		if p := findEndSignature(buf); p >= 0 {
			buf, eocdPos = buf[p:], size-n+int64(p)
			break
		}
		if i == 1 || n == size {
			return 0, errUnsafe
		}
	}
	records := uint64(le.Uint16(buf[10:]))
	dirSize, dirOff := le.Uint32(buf[12:]), le.Uint32(buf[16:])
	if records != 0xffff && dirSize != 0xffffffff && dirOff != 0xffffffff {
		return records, nil
	}
	if eocdPos-locLen < 0 {
		return records, nil
	}
	loc := make([]byte, locLen)
	if _, err := r.ReadAt(loc, eocdPos-locLen); err != nil {
		return 0, err
	}
	if le.Uint32(loc) != 0x07064b50 || le.Uint32(loc[4:]) != 0 || le.Uint32(loc[16:]) != 1 {
		return records, nil // archive/zip ignores an invalid locator
	}
	off := le.Uint64(loc[8:])
	if off > uint64(1<<63-1) {
		return 0, errUnsafe
	}
	rec := make([]byte, eocd64Len)
	if _, err := r.ReadAt(rec, int64(off)); err != nil { // #nosec G115 -- checked above
		return 0, errUnsafe
	}
	if le.Uint32(rec) != 0x06064b50 {
		return 0, errUnsafe
	}
	return le.Uint64(rec[32:]), nil
}

// findEndSignature mirrors archive/zip's findSignatureInBlock, truncated-comment rule included.
func findEndSignature(b []byte) int {
	for i := len(b) - 22; i >= 0; i-- {
		if b[i] == 'P' && b[i+1] == 'K' && b[i+2] == 0x05 && b[i+3] == 0x06 {
			if n := int(b[i+20]) | int(b[i+21])<<8; n+22+i > len(b) {
				return -1
			}
			return i
		}
	}
	return -1
}
