package main
import "log"
import "slices"

// Positive test: slices.RankInt + slices.IsPermutationInt.

fun main() int {
	var pass int = 0

	// RankInt — basic.
	var r1 []int = slices.RankInt(new(4) []int { 40, 10, 30, 20 })
	if len(r1) == 4 { pass = pass + 1 }
	if r1[0] == 4 { pass = pass + 1 }
	if r1[1] == 1 { pass = pass + 1 }
	if r1[2] == 3 { pass = pass + 1 }
	if r1[3] == 2 { pass = pass + 1 }

	// RankInt — ties share rank.
	var r2 []int = slices.RankInt(new(3) []int { 10, 10, 20 })
	if r2[0] == 1 { pass = pass + 1 }
	if r2[1] == 1 { pass = pass + 1 }
	if r2[2] == 3 { pass = pass + 1 }

	// RankInt — all same.
	var r3 []int = slices.RankInt(new(3) []int { 5, 5, 5 })
	if r3[0] == 1 { pass = pass + 1 }
	if r3[1] == 1 { pass = pass + 1 }
	if r3[2] == 1 { pass = pass + 1 }

	// RankInt — sorted ascending.
	var r4 []int = slices.RankInt(new(4) []int { 1, 2, 3, 4 })
	if r4[0] == 1 { pass = pass + 1 }
	if r4[3] == 4 { pass = pass + 1 }

	// RankInt — empty.
	var r5 []int = slices.RankInt(new(0) []int {})
	if len(r5) == 0 { pass = pass + 1 }

	// IsPermutationInt — true cases.
	if slices.IsPermutationInt(new(0) []int {}) { pass = pass + 1 }
	if slices.IsPermutationInt(new(1) []int { 1 }) { pass = pass + 1 }
	if slices.IsPermutationInt(new(3) []int { 1, 2, 3 }) { pass = pass + 1 }
	if slices.IsPermutationInt(new(3) []int { 3, 1, 2 }) { pass = pass + 1 }
	if slices.IsPermutationInt(new(5) []int { 5, 4, 3, 2, 1 }) { pass = pass + 1 }

	// IsPermutationInt — false: missing element.
	if !slices.IsPermutationInt(new(3) []int { 1, 1, 2 }) { pass = pass + 1 }     // dup
	if !slices.IsPermutationInt(new(3) []int { 1, 2, 4 }) { pass = pass + 1 }     // out-of-range
	if !slices.IsPermutationInt(new(3) []int { 0, 1, 2 }) { pass = pass + 1 }     // 0 not allowed
	if !slices.IsPermutationInt(new(2) []int { 1, -1 }) { pass = pass + 1 }       // negative
	if !slices.IsPermutationInt(new(3) []int { 1, 2, 100 }) { pass = pass + 1 }   // too big

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
