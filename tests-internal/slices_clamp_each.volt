package main
import "log"
import "slices"
import "math"

fun main() int {
	var pass int = 0

	// Empty → empty.
	var e []int = new(0) []int {}
	var r1 []int = slices.ClampEachInt(e, 0, 10)
	if len(r1) == 0 { pass = pass + 1 }

	// All in range → unchanged.
	var s1 []int = new(5) []int { 2, 4, 6, 8, 10 }
	var r2 []int = slices.ClampEachInt(s1, 0, 10)
	if len(r2) == 5 { pass = pass + 1 }
	if r2[0] == 2 { pass = pass + 1 }
	if r2[1] == 4 { pass = pass + 1 }
	if r2[2] == 6 { pass = pass + 1 }
	if r2[3] == 8 { pass = pass + 1 }
	if r2[4] == 10 { pass = pass + 1 }

	// Clamp from below.
	var s2 []int = new(5) []int { -5, -2, 0, 3, 8 }
	var r3 []int = slices.ClampEachInt(s2, 0, 10)
	if r3[0] == 0 { pass = pass + 1 }
	if r3[1] == 0 { pass = pass + 1 }
	if r3[2] == 0 { pass = pass + 1 }
	if r3[3] == 3 { pass = pass + 1 }
	if r3[4] == 8 { pass = pass + 1 }

	// Clamp from above.
	var s3 []int = new(5) []int { 1, 5, 10, 15, 100 }
	var r4 []int = slices.ClampEachInt(s3, 0, 10)
	if r4[0] == 1 { pass = pass + 1 }
	if r4[1] == 5 { pass = pass + 1 }
	if r4[2] == 10 { pass = pass + 1 }
	if r4[3] == 10 { pass = pass + 1 }
	if r4[4] == 10 { pass = pass + 1 }

	// Single point range (lo == hi).
	var s4 []int = new(4) []int { 0, 5, 10, 15 }
	var r5 []int = slices.ClampEachInt(s4, 7, 7)
	if r5[0] == 7 { pass = pass + 1 }
	if r5[1] == 7 { pass = pass + 1 }
	if r5[2] == 7 { pass = pass + 1 }
	if r5[3] == 7 { pass = pass + 1 }

	// Degenerate range (hi < lo) → every element becomes lo.
	var s5 []int = new(4) []int { 0, 5, 10, 15 }
	var r6 []int = slices.ClampEachInt(s5, 10, 5)
	if r6[0] == 10 { pass = pass + 1 }
	if r6[1] == 10 { pass = pass + 1 }
	if r6[2] == 10 { pass = pass + 1 }
	if r6[3] == 10 { pass = pass + 1 }

	// Negative range.
	var s6 []int = new(4) []int { -100, -5, 0, 100 }
	var r7 []int = slices.ClampEachInt(s6, -10, -1)
	if r7[0] == -10 { pass = pass + 1 }
	if r7[1] == -5 { pass = pass + 1 }
	if r7[2] == -1 { pass = pass + 1 }
	if r7[3] == -1 { pass = pass + 1 }

	// Doesn't mutate s.
	var s7 []int = new(3) []int { -50, 200, 5 }
	var _r []int = slices.ClampEachInt(s7, 0, 10)
	if s7[0] == -50 { pass = pass + 1 }
	if s7[1] == 200 { pass = pass + 1 }
	if s7[2] == 5 { pass = pass + 1 }

	// Cross-property: every element of ClampEach is in [lo, hi].
	var s8 []int = new(5) []int { -100, 0, 50, 100, 200 }
	var r8 []int = slices.ClampEachInt(s8, 0, 100)
	if math.InRange(r8[0], 0, 100) { pass = pass + 1 }
	if math.InRange(r8[1], 0, 100) { pass = pass + 1 }
	if math.InRange(r8[2], 0, 100) { pass = pass + 1 }
	if math.InRange(r8[3], 0, 100) { pass = pass + 1 }
	if math.InRange(r8[4], 0, 100) { pass = pass + 1 }

	// Color-channel use case: clamp to [0, 255].
	var raw []int = new(4) []int { -10, 50, 200, 999 }
	var rgb []int = slices.ClampEachInt(raw, 0, 255)
	if rgb[0] == 0 { pass = pass + 1 }
	if rgb[1] == 50 { pass = pass + 1 }
	if rgb[2] == 200 { pass = pass + 1 }
	if rgb[3] == 255 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 41 { ret 42 }
	ret 0
}
