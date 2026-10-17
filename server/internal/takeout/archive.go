package takeout

import (
	"archive/zip"
	"cmp"
	"context"
	"errors"
	"fmt"
	"io"
	"io/fs"
	"os"
	"path"
	"slices"
	"strings"
	"sync/atomic"
	"unicode"
	"unicode/utf8"

	"github.com/Paul-Carouge/Alcove/server/internal/drive"
)

// Limits against hostile archives (zip bombs, absurd names). Entry names are never used as paths on
// disk: entries are streamed into files Alcove names itself.
var (
	// A real 50 GB Takeout archive holds a few tens of thousands of entries (a few MB of directory).
	maxEntriesPerArchive = 200_000
	maxEntries           = 1_000_000
	// maxCentralDir bounds the bytes archive/zip may read while parsing an archive's directory, so the
	// headers it allocates (about 46 bytes read each at least).
	maxCentralDir int64 = 48 << 20
	// dirReadSlack covers archive/zip's other reads while parsing: the end records (it searches the last
	// 65 KiB), the ZIP64 records and its read-ahead buffer.
	dirReadSlack int64 = 256 << 10
)

const (
	maxEntryName = 1024
	// maxRatio: photos and videos barely compress; a large entry claiming more is refused, and a job
	// never decompresses more than maxRatio times the size of its archives.
	maxRatio      = 100
	ratioMinBytes = 16 << 20
)

var (
	errTooManyEntries = errors.New("too many entries")
	errUnsafe         = errors.New("unsafe archive")
	errSuspicious     = errors.New("suspicious compression ratio")
	errTooLarge       = errors.New("entry too large")
	errSizeMismatch   = errors.New("entry size does not match the archive's directory")
	errBudget         = errors.New("decompression budget exceeded")
	errNotRegular     = errors.New("not a regular file")
)

// entry is a file inside one of the job's archives or folders.
type entry struct {
	src  int       // index in archives.srcs
	zf   *zip.File // nil for a file of an extracted folder
	path string    // cleaned slash path ("Takeout/Google Photos/Trip/a.jpg")
	size int64     // uncompressed size, as declared (drive.MaxFileSize+1 when larger)
}

func (e entry) dir() string  { return path.Dir(e.path) }
func (e entry) name() string { return path.Base(e.path) }

// contentKey identifies an entry's content without reading it (album copies share it).
func (e entry) contentKey() string {
	if e.zf != nil {
		return fmt.Sprintf("%08x/%d", e.zf.CRC32, e.size)
	}
	return e.path
}

// source is one archive or extracted folder.
type source struct {
	zip    *zip.Reader
	file   *os.File // the archive
	size   int64    // of the archive
	folder *os.Root // an extracted folder
}

// archives are the opened sources of a job.
type archives struct {
	srcs []source
	// budget is what may still be decompressed (nil: unlimited).
	budget *atomic.Int64
}

func (a *archives) Close() {
	for _, s := range a.srcs {
		if s.file != nil {
			_ = s.file.Close()
		}
		if s.folder != nil {
			_ = s.folder.Close()
		}
	}
}

// openSources opens names inside root: .zip files or folders. root confines every access (no "..",
// no symbolic link leading outside). Each archive's central directory is checked before archive/zip
// loads it, and the entries must not overlap (one compressed stream read many times).
func openSources(root *os.Root, names []string) (*archives, error) {
	a := &archives{}
	total := 0
	fail := func(err error) (*archives, error) {
		a.Close()
		return nil, err
	}
	for _, name := range names {
		info, err := root.Lstat(name)
		if err != nil {
			return fail(err)
		}
		switch {
		case info.IsDir():
			sub, err := root.OpenRoot(name)
			if err != nil {
				return fail(err)
			}
			a.srcs = append(a.srcs, source{folder: sub})
		case info.Mode().IsRegular():
			f, err := root.Open(name)
			if err != nil {
				return fail(err)
			}
			a.srcs = append(a.srcs, source{file: f, size: info.Size()})
			zr, err := openZip(f, info.Size())
			if err != nil {
				return fail(fmt.Errorf("%s: %w", name, err))
			}
			if total += len(zr.File); total > maxEntries {
				return fail(errTooManyEntries)
			}
			if err := checkOverlap(zr, info.Size()); err != nil {
				return fail(fmt.Errorf("%s: %w", name, err))
			}
			a.srcs[len(a.srcs)-1].zip = zr
		default:
			return fail(fmt.Errorf("%s: not a file or folder", name))
		}
	}
	return a, nil
}

// openZip parses an archive's directory with bounded memory: the declared entry count is checked
// before archive/zip preallocates it, and what it reads while parsing is capped.
func openZip(r io.ReaderAt, size int64) (*zip.Reader, error) {
	records, err := declaredRecords(r, size)
	if err != nil {
		return nil, err
	}
	if records > uint64(maxEntriesPerArchive) { // #nosec G115 -- a small positive limit
		return nil, errTooManyEntries
	}
	// The end records and the directory, plus a little for the reads around them.
	br := newBudgetReaderAt(r, maxCentralDir+dirReadSlack)
	zr, err := zip.NewReader(br, size)
	if br.exceeded.Load() || errors.Is(err, errUnsafe) {
		return nil, fmt.Errorf("central directory too large: %w", errUnsafe)
	}
	if err != nil {
		return nil, err
	}
	br.lift()
	if len(zr.File) > maxEntriesPerArchive {
		return nil, errTooManyEntries
	}
	return zr, nil
}

// checkOverlap refuses archives whose entries share bytes, or point past the end of the file.
func checkOverlap(zr *zip.Reader, size int64) error {
	type span struct{ start, end int64 }
	spans := make([]span, 0, len(zr.File))
	for _, f := range zr.File {
		if f.CompressedSize64 == 0 {
			continue
		}
		off, err := f.DataOffset()
		if err != nil || size < 0 || f.CompressedSize64 > uint64(size) { // #nosec G115 -- size >= 0
			return errUnsafe
		}
		n := int64(f.CompressedSize64) // #nosec G115 -- at most size
		if off < 0 || off > size-n {
			return errUnsafe
		}
		spans = append(spans, span{off, off + n})
	}
	slices.SortFunc(spans, func(x, y span) int { return cmp.Compare(x.start, y.start) })
	for i := 1; i < len(spans); i++ {
		if spans[i].start < spans[i-1].end {
			return errUnsafe
		}
	}
	return nil
}

// entries lists every regular file of every source, skipping unsafe names.
func (a *archives) entries(ctx context.Context) ([]entry, error) {
	var out []entry
	for i, s := range a.srcs {
		n := 0
		add := func(e entry) error {
			if n++; n > maxEntriesPerArchive || len(out) >= maxEntries {
				return errTooManyEntries
			}
			if n%4096 == 0 && ctx.Err() != nil {
				return ctx.Err()
			}
			if e.size < 0 || e.size > drive.MaxFileSize {
				e.size = drive.MaxFileSize + 1 // refused when read; keeps sums far from overflowing
			}
			out = append(out, e)
			return nil
		}
		if s.zip != nil {
			for _, f := range s.zip.File {
				p, ok := cleanEntryPath(f.Name)
				if !ok || f.FileInfo().IsDir() || !f.Mode().IsRegular() {
					continue
				}
				if err := add(entry{src: i, zf: f, path: p, size: int64(min(f.UncompressedSize64, 1<<62))}); err != nil {
					return nil, err
				}
			}
			continue
		}
		err := fs.WalkDir(s.folder.FS(), ".", func(p string, d fs.DirEntry, err error) error {
			if err != nil {
				return err
			}
			if strings.HasPrefix(d.Name(), ".") && p != "." {
				if d.IsDir() {
					return fs.SkipDir
				}
				return nil
			}
			if !d.Type().IsRegular() { // folders are walked; symbolic links and devices are ignored
				return nil
			}
			info, err := d.Info()
			if err != nil || hardLinked(info) { // a hard link may point anywhere on the volume
				return nil
			}
			if cp, ok := cleanEntryPath(p); ok {
				return add(entry{src: i, path: cp, size: info.Size()})
			}
			return nil
		})
		if err != nil {
			return nil, err
		}
	}
	return out, nil
}

// setBudget allows maxRatio times the archives' size (twice the files' size for folders).
func (a *archives) setBudget(entries []entry) {
	var total int64
	for _, s := range a.srcs {
		total = satAdd(total, satMul(s.size, maxRatio))
	}
	for _, e := range entries {
		if e.zf == nil {
			total = satAdd(total, satMul(e.size, 2))
		}
	}
	a.budget = &atomic.Int64{}
	a.budget.Store(satAdd(total, 64<<20))
}

// cleanEntryPath validates an entry name: relative, slash-separated, no "." or ".." component, no
// control characters, valid UTF-8, bounded length. Invisible format characters (bidi overrides,
// zero-width) become "_" so a name cannot disguise itself.
func cleanEntryPath(name string) (string, bool) {
	if name == "" || len(name) > maxEntryName || !utf8.ValidString(name) || strings.ContainsAny(name, "\\") ||
		strings.HasPrefix(name, "/") {
		return "", false
	}
	for _, r := range name {
		if unicode.IsControl(r) {
			return "", false
		}
	}
	name = strings.Map(func(r rune) rune {
		if unicode.Is(unicode.Cf, r) {
			return '_'
		}
		return r
	}, name)
	for part := range strings.SplitSeq(strings.TrimSuffix(name, "/"), "/") {
		if part == "" || part == "." || part == ".." {
			return "", false
		}
	}
	return name, true
}

// open streams an entry, refusing zip bombs; every byte counts against the job's budget.
func (a *archives) open(e entry) (io.ReadCloser, error) {
	if e.size > drive.MaxFileSize {
		return nil, errTooLarge
	}
	s := a.srcs[e.src]
	var rc io.ReadCloser
	if e.zf == nil {
		f, err := s.folder.Open(e.path)
		if err != nil {
			return nil, err
		}
		if st, err := f.Stat(); err != nil || !st.Mode().IsRegular() || hardLinked(st) {
			_ = f.Close()
			return nil, errNotRegular
		}
		rc = f
	} else {
		if e.zf.UncompressedSize64 > ratioMinBytes && e.zf.UncompressedSize64 > maxRatio*max(e.zf.CompressedSize64, 1) {
			return nil, errSuspicious
		}
		var err error
		if rc, err = e.zf.Open(); err != nil {
			return nil, err
		}
	}
	if a.budget == nil {
		return rc, nil
	}
	return &budgetReader{ReadCloser: rc, budget: a.budget}, nil
}

type budgetReader struct {
	io.ReadCloser
	budget *atomic.Int64
}

func (b *budgetReader) Read(p []byte) (int, error) {
	n, err := b.ReadCloser.Read(p)
	if b.budget.Add(-int64(n)) < 0 {
		return n, errBudget
	}
	return n, err
}

// ctxReader stops a copy as soon as the job is cancelled.
type ctxReader struct {
	ctx context.Context
	r   io.Reader
}

func (c ctxReader) Read(p []byte) (int, error) {
	if err := c.ctx.Err(); err != nil {
		return 0, err
	}
	return c.r.Read(p)
}

// copyEntry writes an entry to w (at most its declared size) and returns the number of bytes.
func (a *archives) copyEntry(ctx context.Context, e entry, w io.Writer) (int64, error) {
	r, err := a.open(e)
	if err != nil {
		return 0, err
	}
	defer func() { _ = r.Close() }()
	n, err := io.Copy(w, ctxReader{ctx, io.LimitReader(r, e.size+1)})
	if err != nil {
		return n, err
	}
	if n != e.size {
		return n, errSizeMismatch
	}
	return n, nil
}

// satAdd and satMul saturate instead of overflowing.
func satAdd(a, b int64) int64 {
	if b > 0 && a > (1<<63-1)-b {
		return 1<<63 - 1
	}
	return a + b
}

func satMul(a, b int64) int64 {
	if a > 0 && b > 0 && a > (1<<63-1)/b {
		return 1<<63 - 1
	}
	return a * b
}
