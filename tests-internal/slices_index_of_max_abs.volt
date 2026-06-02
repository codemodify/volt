package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → -1.
	var e []int = new(0) []int {}
	if slices.IndexOfMaxAbsInt(e) == -1 { pass = pass + 1 }
	var e2 []int = new(0) []int {}
	if slices.IndexOfMinAbsInt(e2) == -1 { pass = pass + 1 }

	// Single → 0.
	var s1 []int = new(1) []int { 42 }
	if slices.IndexOfMaxAbsInt(s1) == 0 { pass = pass + 1 }
	var s1b []int = new(1) []int { -7 }
	if slices.IndexOfMaxAbsInt(s1b) == 0 { pass = pass + 1 }

	// Peak in middle.
	var s2 []int = new(5) []int { 3, -10, 5, 7, -2 }
	if slices.IndexOfMaxAbsInt(s2) == 1 { pass = pass + 1 }

	// Peak at end.
	var s3 []int = new(5) []int { 1, 2, 3, 4, -100 }
	if slices.IndexOfMaxAbsInt(s3) == 4 { pass = pass + 1 }

	// All positive.
	var s4 []int = new(4) []int { 1, 5, 3, 2 }
	if slices.IndexOfMaxAbsInt(s4) == 1 { pass = pass + 1 }
	var s4b []int = new(4) []int { 1, 5, 3, 2 }
	if slices.IndexOfMinAbsInt(s4b) == 0 { pass = pass + 1 }

	// All negative.
	var s5 []int = new(4) []int { -1, -5, -3, -2 }
	if slices.IndexOfMaxAbsInt(s5) == 1 { pass = pass + 1 }
	var s5b []int = new(4) []int { -1, -5, -3, -2 }
	if slices.IndexOfMinAbsInt(s5b) == 0 { pass = pass + 1 }

	// Tie → earliest.
	var s6 []int = new(4) []int { 5, -5, 5, -5 }
	if slices.IndexOfMaxAbsInt(s6) == 0 { pass = pass + 1 }
	var s6b []int = new(3) []int { 7, 7, 7 }
	if slices.IndexOfMinAbsInt(s6b) == 0 { pass = pass + 1 }

	// Zero present.
	var s7 []int = new(4) []int { -5, 0, 3, -2 }
	if slices.IndexOfMinAbsInt(s7) == 1 { pass = pass + 1 }
	var s7b []int = new(4) []int { -5, 0, 3, -2 }
	if slices.IndexOfMaxAbsInt(s7b) == 0 { pass = pass + 1 }

	// Mixed signs.
	var s8 []int = new(5) []int { 100, -200, 50, -300, 75 }
	if slices.IndexOfMaxAbsInt(s8) == 3 { pass = pass + 1 }
	var s8b []int = new(5) []int { 100, -200, 50, -300, 75 }
	if slices.IndexOfMinAbsInt(s8b) == 2 { pass = pass + 1 }   // |50| = 50, smallest

	// Doesn't mutate.
	var s9 []int = new(3) []int { -5, 3, -7 }
	var _i int = slices.IndexOfMaxAbsInt(s9)
	if s9[0] == -5 { pass = pass + 1 }
	if s9[1] == 3 { pass = pass + 1 }
	if s9[2] == -7 { pass = pass + 1 }

	// Cross-property: abs(s[IndexOfMaxAbs]) == MaxAbs.
	var s10 []int = new(5) []int { 3, -10, 5, 7, -2 }
	var s10b []int = new(5) []int { 3, -10, 5, 7, -2 }
	var idx int = slices.IndexOfMaxAbsInt(s10)
	var peak int = s10b[idx]
	if peak < 0 { peak = -peak }
	var s10c []int = new(5) []int { 3, -10, 5, 7, -2 }
	if peak == slices.MaxAbsInt(s10c) { pass = pass + 1 }

	// Signal-peak use case.
	var samples []int = new(7) []int { 10, -20, 5, 30, -50, 15, -8 }
	if slices.IndexOfMaxAbsInt(samples) == 4 { pass = pass + 1 }   // |-50| = 50 wins

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
