package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	var r1 []int = slices.PercentOfTotalInt(e, 100)
	if len(r1) == 0 { pass = pass + 1 }

	// All zero.
	var s1 []int = new(3) []int { 0, 0, 0 }
	var r2 []int = slices.PercentOfTotalInt(s1, 100)
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 0 { pass = pass + 1 }
	if r2[1] == 0 { pass = pass + 1 }
	if r2[2] == 0 { pass = pass + 1 }

	// Single element gets 100% (or full scale).
	var s2 []int = new(1) []int { 7 }
	var r3 []int = slices.PercentOfTotalInt(s2, 100)
	if r3[0] == 100 { pass = pass + 1 }

	// Even split.
	var s3 []int = new(4) []int { 25, 25, 25, 25 }
	var r4 []int = slices.PercentOfTotalInt(s3, 100)
	if r4[0] == 25 { pass = pass + 1 }
	if r4[1] == 25 { pass = pass + 1 }
	if r4[2] == 25 { pass = pass + 1 }
	if r4[3] == 25 { pass = pass + 1 }

	// Custom scale: permille.
	var s4 []int = new(2) []int { 1, 3 }
	var r5 []int = slices.PercentOfTotalInt(s4, 1000)
	if r5[0] == 250 { pass = pass + 1 }
	if r5[1] == 750 { pass = pass + 1 }

	// Truncation: 100 / 3 = 33 per cell.
	var s5 []int = new(3) []int { 1, 1, 1 }
	var r6 []int = slices.PercentOfTotalInt(s5, 100)
	if r6[0] == 33 { pass = pass + 1 }
	if r6[1] == 33 { pass = pass + 1 }
	if r6[2] == 33 { pass = pass + 1 }

	// Asymmetric split.
	var s6 []int = new(3) []int { 50, 30, 20 }
	var r7 []int = slices.PercentOfTotalInt(s6, 100)
	if r7[0] == 50 { pass = pass + 1 }
	if r7[1] == 30 { pass = pass + 1 }
	if r7[2] == 20 { pass = pass + 1 }

	// Doesn't mutate s.
	var s7 []int = new(3) []int { 10, 20, 30 }
	var _r []int = slices.PercentOfTotalInt(s7, 100)
	if s7[0] == 10 { pass = pass + 1 }
	if s7[1] == 20 { pass = pass + 1 }
	if s7[2] == 30 { pass = pass + 1 }

	// Cross-property: when total divides scale evenly, sum of outputs equals scale.
	var s8 []int = new(4) []int { 1, 2, 3, 4 }
	var r8 []int = slices.PercentOfTotalInt(s8, 100)
	var sum int = r8[0] + r8[1] + r8[2] + r8[3]
	if sum == 100 { pass = pass + 1 }   // 10 + 20 + 30 + 40

	// Budget-split use case.
	var spending []int = new(4) []int { 1200, 800, 500, 500 }   // total = 3000
	var pct []int = slices.PercentOfTotalInt(spending, 100)
	if pct[0] == 40 { pass = pass + 1 }
	if pct[1] == 26 { pass = pass + 1 }   // 800/3000 = 26.66... → 26
	if pct[2] == 16 { pass = pass + 1 }
	if pct[3] == 16 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
