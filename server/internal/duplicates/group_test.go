package duplicates_test

import (
	"fmt"
	"math/rand/v2"
	"testing"

	"github.com/Paul-Carouge/Alcove/server/internal/duplicates"
)

// hex is a fingerprint with a mid-grey average colour.
func hex(h uint64) string { return fmt.Sprintf("%016x808080", h) }

func TestGroup(t *testing.T) {
	base := uint64(0xF0F0_1234_ABCD_5678)
	items := []duplicates.Item{
		{ID: "a", SHA256: "s1", PHash: hex(base), Image: true, Ratio: 1.5},
		{ID: "a-copy", SHA256: "s1", PHash: hex(base), Image: true, Ratio: 1.5},              // identical
		{ID: "a-resized", SHA256: "s2", PHash: hex(base ^ 0b10101), Image: true, Ratio: 1.5}, // 3 bits off
		{ID: "other", SHA256: "s3", PHash: hex(^base), Image: true, Ratio: 1.5},              // unrelated
		{ID: "far", SHA256: "s4", PHash: hex(base ^ 0xFE00), Image: true, Ratio: 1.5},        // 7 bits from a, 10 from a-resized
		{ID: "video", SHA256: "s5", PHash: hex(base), Image: false},                          // videos only match exactly
		{ID: "v-copy", SHA256: "s5", Image: false},
		{ID: "sky", SHA256: "s6", PHash: hex(0xFFFF_FFFF_FFFF_FFFF), Image: true}, // flat: never "similar"
		{ID: "sky2", SHA256: "s7", PHash: hex(0xFFFF_FFFF_FFFF_FFFE), Image: true},
		{ID: "crop", SHA256: "s8", PHash: hex(base ^ 1), Image: true, Ratio: 1}, // square crop
		{ID: "crop2", SHA256: "s9", PHash: hex(base ^ 2), Image: true, Ratio: 1.5},
		{ID: "pink", SHA256: "s10", PHash: hex(base ^ 4)[:16] + "e0a0b0", Image: true, Ratio: 1.5}, // same layout, other colours
	}
	got := duplicates.Group(items)
	want := [][]int{{0, 1, 2, 10}, {5, 6}} // crop2 has the same shape; crop does not
	if fmt.Sprint(got) != fmt.Sprint(want) {
		t.Fatalf("groups = %v, want %v", got, want)
	}
}

// The chunked search must find every pair within the threshold, like a brute-force comparison.
func TestGroupMatchesBruteForce(t *testing.T) {
	r := rand.New(rand.NewPCG(1, 2))
	var items []duplicates.Item
	for i := range 400 {
		h := r.Uint64()
		if i%3 == 0 && i > 0 {
			// a near copy of an earlier item, with up to 8 flipped bits
			src := items[r.IntN(len(items))].PHash
			var b uint64
			_, _ = fmt.Sscanf(src[:16], "%x", &b)
			for range r.IntN(9) {
				b ^= 1 << r.IntN(64)
			}
			h = b
		}
		items = append(items, duplicates.Item{ID: fmt.Sprint(i), SHA256: fmt.Sprint(i), PHash: hex(h), Image: true})
	}
	got := map[int]int{}
	for g, set := range duplicates.Group(items) {
		for _, i := range set {
			got[i] = g
		}
	}
	for i := range items {
		for j := i + 1; j < len(items); j++ {
			var a, b uint64
			_, _ = fmt.Sscanf(items[i].PHash[:16], "%x", &a)
			_, _ = fmt.Sscanf(items[j].PHash[:16], "%x", &b)
			d := 0
			for x := a ^ b; x != 0; x &= x - 1 {
				d++
			}
			if d <= duplicates.Threshold {
				gi, oki := got[i]
				gj, okj := got[j]
				if !oki || !okj || gi != gj {
					t.Fatalf("items %d and %d are %d bits apart but not grouped", i, j, d)
				}
			}
		}
	}
}
