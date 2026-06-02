package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → 0.
	var e []int = new(0) []int {}
	if slices.MaxAbsInt(e) == 0 { pass = pass + 1 }
	var e2 []int = new(0) []int {}
	if slices.MinAbsInt(e2) == 0 { pass = pass + 1 }

	// Single.
	var s1 []int = new(1) []int { 7 }
	if slices.MaxAbsInt(s1) == 7 { pass = pass + 1 }
	var s1b []int = new(1) []int { -7 }
	if slices.MaxAbsInt(s1b) == 7 { pass = pass + 1 }
	var s1c []int = new(1) []int { 7 }
	if slices.MinAbsInt(s1c) == 7 { pass = pass + 1 }

	// All positive.
	var s2 []int = new(4) []int { 3, 1, 4, 2 }
	if slices.MaxAbsInt(s2) == 4 { pass = pass + 1 }
	var s2b []int = new(4) []int { 3, 1, 4, 2 }
	if slices.MinAbsInt(s2b) == 1 { pass = pass + 1 }

	// All negative.
	var s3 []int = new(4) []int { -3, -1, -4, -2 }
	if slices.MaxAbsInt(s3) == 4 { pass = pass + 1 }
	var s3b []int = new(4) []int { -3, -1, -4, -2 }
	if slices.MinAbsInt(s3b) == 1 { pass = pass + 1 }

	// Mixed signs.
	var s4 []int = new(5) []int { -5, 3, -2, 7, -1 }
	if slices.MaxAbsInt(s4) == 7 { pass = pass + 1 }
	var s4b []int = new(5) []int { -5, 3, -2, 7, -1 }
	if slices.MinAbsInt(s4b) == 1 { pass = pass + 1 }

	// With zero.
	var s5 []int = new(4) []int { -5, 0, 3, -2 }
	if slices.MaxAbsInt(s5) == 5 { pass = pass + 1 }
	var s5b []int = new(4) []int { -5, 0, 3, -2 }
	if slices.MinAbsInt(s5b) == 0 { pass = pass + 1 }

	// All zeros.
	var s6 []int = new(3) []int { 0, 0, 0 }
	if slices.MaxAbsInt(s6) == 0 { pass = pass + 1 }
	var s6b []int = new(3) []int { 0, 0, 0 }
	if slices.MinAbsInt(s6b) == 0 { pass = pass + 1 }

	// MaxAbs >= MinAbs.
	var s7 []int = new(5) []int { -5, 3, -2, 7, -1 }
	var s7b []int = new(5) []int { -5, 3, -2, 7, -1 }
	if slices.MaxAbsInt(s7) >= slices.MinAbsInt(s7b) { pass = pass + 1 }

	// Doesn't mutate s.
	var s8 []int = new(4) []int { -5, 3, -2, 7 }
	var _r int = slices.MaxAbsInt(s8)
	var _r2 int = slices.MinAbsInt(s8)
	if s8[0] == -5 { pass = pass + 1 }
	if s8[1] == 3 { pass = pass + 1 }
	if s8[2] == -2 { pass = pass + 1 }
	if s8[3] == 7 { pass = pass + 1 }

	// Peak-amplitude use case: signal samples.
	var samples []int = new(7) []int { 100, -200, 50, 300, -400, 150, -75 }
	if slices.MaxAbsInt(samples) == 400 { pass = pass + 1 }

	// Closest-to-zero use case.
	var deviations []int = new(5) []int { -50, 25, -10, 80, -100 }
	if slices.MinAbsInt(deviations) == 10 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
