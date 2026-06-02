package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	if slices.CountInRangeInt(e, 0, 10) == 0 { pass = pass + 1 }
	var e2 []int = new(0) []int {}
	var f0 []int = slices.FilterInRangeInt(e2, 0, 10)
	if len(f0) == 0 { pass = pass + 1 }

	// Degenerate range.
	var s1 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.CountInRangeInt(s1, 10, 0) == 0 { pass = pass + 1 }
	var s1b []int = new(5) []int { 1, 2, 3, 4, 5 }
	var f1 []int = slices.FilterInRangeInt(s1b, 10, 0)
	if len(f1) == 0 { pass = pass + 1 }

	// All in range.
	var s2 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.CountInRangeInt(s2, 0, 10) == 5 { pass = pass + 1 }
	var s2b []int = new(5) []int { 1, 2, 3, 4, 5 }
	var f2 []int = slices.FilterInRangeInt(s2b, 0, 10)
	if len(f2) == 5 { pass = pass + 1 }
	if f2[0] == 1 { pass = pass + 1 }
	if f2[4] == 5 { pass = pass + 1 }

	// All outside.
	var s3 []int = new(3) []int { 100, 200, 300 }
	if slices.CountInRangeInt(s3, 0, 10) == 0 { pass = pass + 1 }
	var s3b []int = new(3) []int { 100, 200, 300 }
	var f3 []int = slices.FilterInRangeInt(s3b, 0, 10)
	if len(f3) == 0 { pass = pass + 1 }

	// Mixed: some in, some out.
	var s4 []int = new(8) []int { -5, 0, 3, 7, 10, 15, 100, -10 }
	if slices.CountInRangeInt(s4, 0, 10) == 4 { pass = pass + 1 }   // 0,3,7,10
	var s4b []int = new(8) []int { -5, 0, 3, 7, 10, 15, 100, -10 }
	var f4 []int = slices.FilterInRangeInt(s4b, 0, 10)
	if len(f4) == 4 { pass = pass + 1 }
	if f4[0] == 0 { pass = pass + 1 }
	if f4[1] == 3 { pass = pass + 1 }
	if f4[2] == 7 { pass = pass + 1 }
	if f4[3] == 10 { pass = pass + 1 }

	// Boundary-inclusive (lo and hi both kept).
	var s5 []int = new(3) []int { 0, 5, 10 }
	if slices.CountInRangeInt(s5, 0, 10) == 3 { pass = pass + 1 }
	var s5b []int = new(3) []int { 0, 5, 10 }
	var f5 []int = slices.FilterInRangeInt(s5b, 0, 10)
	if len(f5) == 3 { pass = pass + 1 }

	// Single-point range (lo == hi) — only exact value kept.
	var s6 []int = new(5) []int { 4, 5, 5, 6, 5 }
	if slices.CountInRangeInt(s6, 5, 5) == 3 { pass = pass + 1 }
	var s6b []int = new(5) []int { 4, 5, 5, 6, 5 }
	var f6 []int = slices.FilterInRangeInt(s6b, 5, 5)
	if len(f6) == 3 { pass = pass + 1 }

	// Negative range.
	var s7 []int = new(5) []int { -10, -5, 0, 5, 10 }
	if slices.CountInRangeInt(s7, -7, -3) == 1 { pass = pass + 1 }
	var s7b []int = new(5) []int { -10, -5, 0, 5, 10 }
	var f7 []int = slices.FilterInRangeInt(s7b, -7, -3)
	if len(f7) == 1 { pass = pass + 1 }
	if f7[0] == -5 { pass = pass + 1 }

	// Cross-property: CountInRange == len(FilterInRange).
	var s8 []int = new(6) []int { 1, 3, 5, 7, 9, 11 }
	var s8b []int = new(6) []int { 1, 3, 5, 7, 9, 11 }
	var c1 int = slices.CountInRangeInt(s8, 4, 8)
	var fInr []int = slices.FilterInRangeInt(s8b, 4, 8)
	if c1 == len(fInr) { pass = pass + 1 }

	// Doesn't mutate s.
	var s9 []int = new(4) []int { 3, 1, 4, 1 }
	var _c int = slices.CountInRangeInt(s9, 0, 5)
	if s9[0] == 3 { pass = pass + 1 }
	if s9[1] == 1 { pass = pass + 1 }
	if s9[2] == 4 { pass = pass + 1 }
	if s9[3] == 1 { pass = pass + 1 }

	// Histogram-bin use case.
	var ages []int = new(10) []int { 18, 25, 32, 45, 17, 65, 28, 19, 70, 40 }
	if slices.CountInRangeInt(ages, 18, 29) == 4 { pass = pass + 1 }   // 18,25,28,19

	log.Println("pass=%d", pass)
	if pass == 29 { ret 42 }
	ret 0
}
