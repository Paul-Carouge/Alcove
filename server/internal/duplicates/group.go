// Package duplicates finds identical files and visually similar photos among a user's items (v0.13).
package duplicates

import (
	"math"
	"math/bits"
	"slices"
	"strconv"
)

// Threshold is the largest dHash distance (out of 64 bits) for two photos to count as similar: resized
// or recompressed copies are usually within 2-4 bits, bursts a little more.
const Threshold = 6

// chunks splits 64 bits into Threshold+1 parts: two hashes within Threshold bits share at least one part
// exactly (pigeonhole), so only items sharing a part need comparing.
var chunks = func() [][2]uint {
	n := uint(Threshold + 1)
	out := make([][2]uint, 0, n)
	start := uint(0)
	for i := range n {
		size := 64 / n
		if i < 64%n {
			size++
		}
		out = append(out, [2]uint{start, size})
		start += size
	}
	return out
}()

// Item is what grouping needs from a media record.
type Item struct {
	ID     string
	SHA256 string
	PHash  string  // 16 hex digits of dHash + 6 of average colour, or empty
	Image  bool    // similar-photo matching only applies to images
	Ratio  float64 // width / height; 0 when unknown
}

// informative rejects hashes of nearly flat or smoothly graded pictures (skies, gradients, blank pages):
// most of their bits agree by construction, so they would match each other without looking alike.
func informative(h uint64) bool {
	n := bits.OnesCount64(h)
	return n >= 8 && n <= 56
}

// MaxColorDistance is the largest distance between average colours (RGB, 0-441) of similar photos:
// the brightness hash alone cannot tell a green picture from a pink one with the same layout.
const MaxColorDistance = 48

func sameColor(a, b [3]float64) bool {
	d := 0.0
	for i := range a {
		d += (a[i] - b[i]) * (a[i] - b[i])
	}
	return math.Sqrt(d) <= MaxColorDistance
}

func parseColor(s string) ([3]float64, bool) {
	v, err := strconv.ParseUint(s, 16, 32)
	if err != nil || len(s) != 6 {
		return [3]float64{}, false
	}
	return [3]float64{float64(v >> 16 & 0xff), float64(v >> 8 & 0xff), float64(v & 0xff)}, true
}

// sameShape keeps resized copies and bursts (same proportions) and rejects crops and rotations.
func sameShape(a, b float64) bool {
	if a == 0 || b == 0 {
		return true
	}
	return math.Abs(a/b-1) < 0.03
}

// Group returns the indexes of items that are duplicates of each other: same SHA-256, or images whose
// perceptual hashes are within Threshold bits. Each group has at least two items.
func Group(items []Item) [][]int {
	parent := make([]int, len(items))
	for i := range parent {
		parent[i] = i
	}
	find := func(i int) int {
		for parent[i] != i {
			parent[i] = parent[parent[i]]
			i = parent[i]
		}
		return i
	}
	union := func(a, b int) {
		if ra, rb := find(a), find(b); ra != rb {
			parent[rb] = ra
		}
	}

	bySHA := map[string]int{}
	hashes := make([]uint64, len(items))
	colors := make([][3]float64, len(items))
	hasHash := make([]bool, len(items))
	for i, it := range items {
		if it.SHA256 != "" {
			if j, ok := bySHA[it.SHA256]; ok {
				union(j, i)
				continue // identical copies are compared through their first occurrence
			}
			bySHA[it.SHA256] = i
		}
		if len(it.PHash) != 22 || !it.Image {
			continue
		}
		h, err := strconv.ParseUint(it.PHash[:16], 16, 64)
		c, ok := parseColor(it.PHash[16:])
		if err == nil && ok && informative(h) {
			hashes[i], colors[i], hasHash[i] = h, c, true
		}
	}

	buckets := map[[2]uint64][]int{}
	for i := range items {
		if !hasHash[i] {
			continue
		}
		for c, ch := range chunks {
			part := (hashes[i] >> (64 - ch[0] - ch[1])) & (1<<ch[1] - 1)
			key := [2]uint64{uint64(c), part}
			for _, j := range buckets[key] {
				if bits.OnesCount64(hashes[i]^hashes[j]) <= Threshold && sameShape(items[i].Ratio, items[j].Ratio) &&
					sameColor(colors[i], colors[j]) {
					union(i, j)
				}
			}
			buckets[key] = append(buckets[key], i)
		}
	}

	sets := map[int][]int{}
	for i := range items {
		r := find(i)
		sets[r] = append(sets[r], i)
	}
	var out [][]int
	for _, s := range sets {
		if len(s) > 1 {
			out = append(out, s)
		}
	}
	slices.SortFunc(out, func(a, b []int) int { return a[0] - b[0] })
	return out
}
