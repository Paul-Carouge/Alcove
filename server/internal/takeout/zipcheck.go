package takeout

import (
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
