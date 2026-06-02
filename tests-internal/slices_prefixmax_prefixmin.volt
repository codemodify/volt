package main
import "log"
import "slices"

// Positive test: slices.PrefixMaxInt + slices.PrefixMinInt.

fun main() int {
	var pass int = 0

	// PrefixMaxInt — basic.
	var p1 []int = slices.PrefixMaxInt(new(5) []int { 3, 1, 4, 1, 5 })
	if len(p1) == 5 { pass = pass + 1 }
	if p1[0] == 3 { pass = pass + 1 }
	if p1[1] == 3 { pass = pass + 1 }
	if p1[2] == 4 { pass = pass + 1 }
	if p1[3] == 4 { pass = pass + 1 }
	if p1[4] == 5 { pass = pass + 1 }

	// PrefixMaxInt — strictly ascending input.
	var p2 []int = slices.PrefixMaxInt(new(4) []int { 1, 2, 3, 4 })
	if p2[0] == 1 { pass = pass + 1 }
	if p2[3] == 4 { pass = pass + 1 }

	// PrefixMaxInt — strictly descending.
	var p3 []int = slices.PrefixMaxInt(new(4) []int { 4, 3, 2, 1 })
	if p3[0] == 4 { pass = pass + 1 }
	if p3[3] == 4 { pass = pass + 1 }

	// PrefixMaxInt — empty.
	var p4 []int = slices.PrefixMaxInt(new(0) []int {})
	if len(p4) == 0 { pass = pass + 1 }

	// PrefixMaxInt — single.
	var p5 []int = slices.PrefixMaxInt(new(1) []int { 42 })
	if p5[0] == 42 { pass = pass + 1 }

	// PrefixMaxInt — non-decreasing invariant.
	var p6 []int = slices.PrefixMaxInt(new(5) []int { 10, -5, 20, 3, 15 })
	if p6[0] == 10 { pass = pass + 1 }
	if p6[1] == 10 { pass = pass + 1 }
	if p6[2] == 20 { pass = pass + 1 }
	if p6[3] == 20 { pass = pass + 1 }
	if p6[4] == 20 { pass = pass + 1 }

	// PrefixMinInt — basic.
	var m1 []int = slices.PrefixMinInt(new(5) []int { 3, 1, 4, 1, 5 })
	if m1[0] == 3 { pass = pass + 1 }
	if m1[1] == 1 { pass = pass + 1 }
	if m1[2] == 1 { pass = pass + 1 }
	if m1[3] == 1 { pass = pass + 1 }
	if m1[4] == 1 { pass = pass + 1 }

	// PrefixMinInt — strictly descending.
	var m2 []int = slices.PrefixMinInt(new(4) []int { 10, 8, 6, 4 })
	if m2[0] == 10 { pass = pass + 1 }
	if m2[3] == 4 { pass = pass + 1 }

	// PrefixMinInt — strictly ascending.
	var m3 []int = slices.PrefixMinInt(new(4) []int { 1, 2, 3, 4 })
	if m3[0] == 1 { pass = pass + 1 }
	if m3[3] == 1 { pass = pass + 1 }

	// PrefixMinInt — empty.
	var m4 []int = slices.PrefixMinInt(new(0) []int {})
	if len(m4) == 0 { pass = pass + 1 }

	// PrefixMinInt — negatives.
	var m5 []int = slices.PrefixMinInt(new(3) []int { -5, -10, -1 })
	if m5[0] == -5 { pass = pass + 1 }
	if m5[1] == -10 { pass = pass + 1 }
	if m5[2] == -10 { pass = pass + 1 }

	// Consistency: PrefixMax[last] == MaxInts.
	var sample []int = new(5) []int { 3, 1, 4, 1, 5 }
	var pm []int = slices.PrefixMaxInt(sample)
	if pm[4] == slices.MaxInts(sample) { pass = pass + 1 }

	var pmin []int = slices.PrefixMinInt(sample)
	if pmin[4] == slices.MinInts(sample) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
