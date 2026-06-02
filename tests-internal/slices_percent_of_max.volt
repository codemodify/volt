package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	var r1 []int = slices.PercentOfMaxInt(e, 100)
	if len(r1) == 0 { pass = pass + 1 }

	// All zeros.
	var s1 []int = new(3) []int { 0, 0, 0 }
	var r2 []int = slices.PercentOfMaxInt(s1, 100)
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 0 { pass = pass + 1 }
	if r2[1] == 0 { pass = pass + 1 }
	if r2[2] == 0 { pass = pass + 1 }

	// Single non-zero gets 100 (or scale).
	var s2 []int = new(1) []int { 5 }
	var r3 []int = slices.PercentOfMaxInt(s2, 100)
	if r3[0] == 100 { pass = pass + 1 }

	// Max element gets scale, others proportional.
	var s3 []int = new(4) []int { 25, 50, 100, 75 }
	var r4 []int = slices.PercentOfMaxInt(s3, 100)
	if r4[0] == 25 { pass = pass + 1 }
	if r4[1] == 50 { pass = pass + 1 }
	if r4[2] == 100 { pass = pass + 1 }
	if r4[3] == 75 { pass = pass + 1 }

	// Custom scale (e.g. width 40 chars for ASCII bar).
	var s4 []int = new(3) []int { 10, 20, 40 }
	var r5 []int = slices.PercentOfMaxInt(s4, 40)
	if r5[0] == 10 { pass = pass + 1 }
	if r5[1] == 20 { pass = pass + 1 }
	if r5[2] == 40 { pass = pass + 1 }

	// Negative values preserve sign.
	var s5 []int = new(4) []int { -10, -5, 0, 5 }
	var r6 []int = slices.PercentOfMaxInt(s5, 100)
	if r6[0] == -100 { pass = pass + 1 }   // |-10| is max
	if r6[1] == -50 { pass = pass + 1 }
	if r6[2] == 0 { pass = pass + 1 }
	if r6[3] == 50 { pass = pass + 1 }

	// Truncation: max=3, values 1,2,3, scale 10 → 3,6,10.
	var s6 []int = new(3) []int { 1, 2, 3 }
	var r7 []int = slices.PercentOfMaxInt(s6, 10)
	if r7[0] == 3 { pass = pass + 1 }
	if r7[1] == 6 { pass = pass + 1 }
	if r7[2] == 10 { pass = pass + 1 }

	// Doesn't mutate s.
	var s7 []int = new(3) []int { 5, 10, 20 }
	var _r []int = slices.PercentOfMaxInt(s7, 100)
	if s7[0] == 5 { pass = pass + 1 }
	if s7[1] == 10 { pass = pass + 1 }
	if s7[2] == 20 { pass = pass + 1 }

	// Cross-property: max output is always == scale.
	var s8 []int = new(5) []int { 30, 70, 100, 50, 80 }
	var s8b []int = new(5) []int { 30, 70, 100, 50, 80 }
	var r8 []int = slices.PercentOfMaxInt(s8, 100)
	var maxOut int = slices.MaxInts(r8)
	if maxOut == 100 { pass = pass + 1 }
	if s8b[2] == 100 { pass = pass + 1 }

	// Bar-chart use case.
	var data []int = new(5) []int { 12, 45, 78, 23, 67 }
	var bars []int = slices.PercentOfMaxInt(data, 40)
	if bars[2] == 40 { pass = pass + 1 }   // 78 is max → 40
	if bars[1] >= 22 { pass = pass + 1 }   // 45*40/78 ≈ 23

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
