package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// NormalizeRangeInt basics: [10,20,30,40] → [0,33,66,100] with [0,100]
	var s1 []int = new(4) []int {10, 20, 30, 40}
	var r1 []int = slices.NormalizeRangeInt(s1, 0, 100)
	if len(r1) == 4 { pass = pass + 1 }
	if r1[0] == 0 { pass = pass + 1 }
	if r1[1] == 33 { pass = pass + 1 }
	if r1[2] == 66 { pass = pass + 1 }
	if r1[3] == 100 { pass = pass + 1 }

	// Empty input.
	var s2 []int = new(0) []int {}
	var r2 []int = slices.NormalizeRangeInt(s2, 0, 100)
	if len(r2) == 0 { pass = pass + 1 }

	// Constant input: all elements equal → all map to `lo`.
	var s3 []int = new(4) []int {5, 5, 5, 5}
	var r3 []int = slices.NormalizeRangeInt(s3, 10, 90)
	if r3[0] == 10 { pass = pass + 1 }
	if r3[1] == 10 { pass = pass + 1 }
	if r3[2] == 10 { pass = pass + 1 }
	if r3[3] == 10 { pass = pass + 1 }

	// Negative range: [-10, 10] → [0, 8].
	// span = 20, range_out = 8.
	// -10 → 0 + ((-10 - -10) * 8)/20 = 0
	// 0   → 0 + ((0 - -10) * 8)/20  = 80/20 = 4
	// 10  → 0 + ((10 - -10) * 8)/20 = 160/20 = 8
	var s4 []int = new(3) []int {-10, 0, 10}
	var r4 []int = slices.NormalizeRangeInt(s4, 0, 8)
	if r4[0] == 0 { pass = pass + 1 }
	if r4[1] == 4 { pass = pass + 1 }
	if r4[2] == 8 { pass = pass + 1 }

	// Single-element: range degenerate, output = lo.
	var s5 []int = new(1) []int {42}
	var r5 []int = slices.NormalizeRangeInt(s5, 7, 99)
	if r5[0] == 7 { pass = pass + 1 }

	// Composition with Sparkline: normalize arbitrary range → sparkline.
	// Just check it doesn't crash and produces the expected length.
	var s6 []int = new(5) []int {100, 200, 50, 175, 300}
	var r6 []int = slices.NormalizeRangeInt(s6, 0, 8)
	if len(r6) == 5 { pass = pass + 1 }

	// IsConstantInt basics.
	if slices.IsConstantInt(new(0) []int {}) { pass = pass + 1 }
	if slices.IsConstantInt(new(1) []int {42}) { pass = pass + 1 }
	var c1 []int = new(4) []int {7, 7, 7, 7}
	if slices.IsConstantInt(c1) { pass = pass + 1 }
	var c2 []int = new(4) []int {7, 7, 8, 7}
	if !slices.IsConstantInt(c2) { pass = pass + 1 }
	var c3 []int = new(2) []int {1, 2}
	if !slices.IsConstantInt(c3) { pass = pass + 1 }
	// Negative all-same.
	var c4 []int = new(3) []int {-5, -5, -5}
	if slices.IsConstantInt(c4) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
