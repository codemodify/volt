package main
import "log"
import "slices"

// Positive test: slices.DifferencesInt + slices.IsMonotonicInt.

fun main() int {
	var pass int = 0

	// DifferencesInt — basic.
	var d1 []int = slices.DifferencesInt(new(5) []int { 1, 3, 6, 10, 15 })
	if len(d1) == 4 { pass = pass + 1 }
	if d1[0] == 2 { pass = pass + 1 }
	if d1[1] == 3 { pass = pass + 1 }
	if d1[2] == 4 { pass = pass + 1 }
	if d1[3] == 5 { pass = pass + 1 }

	// DifferencesInt — negative.
	var d2 []int = slices.DifferencesInt(new(4) []int { 10, 5, 0, -5 })
	if d2[0] == -5 { pass = pass + 1 }
	if d2[3 - 1] == -5 { pass = pass + 1 }   // last == -5

	// DifferencesInt — constant.
	var d3 []int = slices.DifferencesInt(new(4) []int { 7, 7, 7, 7 })
	if d3[0] == 0 { pass = pass + 1 }
	if d3[2] == 0 { pass = pass + 1 }

	// DifferencesInt — empty / single.
	var d4 []int = slices.DifferencesInt(new(0) []int {})
	if len(d4) == 0 { pass = pass + 1 }
	var d5 []int = slices.DifferencesInt(new(1) []int { 42 })
	if len(d5) == 0 { pass = pass + 1 }

	// DifferencesInt — two-element.
	var d6 []int = slices.DifferencesInt(new(2) []int { 1, 5 })
	if len(d6) == 1 { pass = pass + 1 }
	if d6[0] == 4 { pass = pass + 1 }

	// IsMonotonicInt — non-decreasing.
	if slices.IsMonotonicInt(new(4) []int { 1, 2, 3, 4 }) { pass = pass + 1 }
	if slices.IsMonotonicInt(new(4) []int { 1, 2, 2, 3 }) { pass = pass + 1 }   // ties OK

	// IsMonotonicInt — non-increasing.
	if slices.IsMonotonicInt(new(4) []int { 4, 3, 2, 1 }) { pass = pass + 1 }
	if slices.IsMonotonicInt(new(4) []int { 4, 4, 2, 1 }) { pass = pass + 1 }

	// IsMonotonicInt — constant is monotonic.
	if slices.IsMonotonicInt(new(3) []int { 5, 5, 5 }) { pass = pass + 1 }

	// IsMonotonicInt — empty / single / two-element.
	if slices.IsMonotonicInt(new(0) []int {}) { pass = pass + 1 }
	if slices.IsMonotonicInt(new(1) []int { 42 }) { pass = pass + 1 }
	if slices.IsMonotonicInt(new(2) []int { 1, 2 }) { pass = pass + 1 }
	if slices.IsMonotonicInt(new(2) []int { 2, 1 }) { pass = pass + 1 }

	// IsMonotonicInt — not monotonic.
	if !slices.IsMonotonicInt(new(4) []int { 1, 3, 2, 4 }) { pass = pass + 1 }
	if !slices.IsMonotonicInt(new(5) []int { 5, 3, 7, 1, 9 }) { pass = pass + 1 }

	// IsMonotonicInt — strictly increasing remains monotonic.
	if slices.IsMonotonicInt(new(4) []int { -5, -2, 0, 7 }) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
