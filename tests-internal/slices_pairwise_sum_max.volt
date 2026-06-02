package main
import "log"
import "slices"

// Positive test: slices.PairwiseSumInt + slices.PairwiseMaxInt.

fun main() int {
	var pass int = 0

	// PairwiseSumInt — basic.
	var s1 []int = slices.PairwiseSumInt(new(5) []int { 1, 2, 3, 4, 5 })
	if len(s1) == 4 { pass = pass + 1 }
	if s1[0] == 3 { pass = pass + 1 }
	if s1[1] == 5 { pass = pass + 1 }
	if s1[2] == 7 { pass = pass + 1 }
	if s1[3] == 9 { pass = pass + 1 }

	// PairwiseSumInt — negatives.
	var s2 []int = slices.PairwiseSumInt(new(3) []int { -1, 0, 1 })
	if s2[0] == -1 { pass = pass + 1 }
	if s2[1] == 1 { pass = pass + 1 }

	// PairwiseSumInt — len < 2 → empty.
	var s3 []int = slices.PairwiseSumInt(new(1) []int { 5 })
	if len(s3) == 0 { pass = pass + 1 }
	var s4 []int = slices.PairwiseSumInt(new(0) []int {})
	if len(s4) == 0 { pass = pass + 1 }

	// PairwiseSumInt — two elements.
	var s5 []int = slices.PairwiseSumInt(new(2) []int { 10, 20 })
	if len(s5) == 1 { pass = pass + 1 }
	if s5[0] == 30 { pass = pass + 1 }

	// PairwiseMaxInt — basic.
	var m1 []int = slices.PairwiseMaxInt(new(5) []int { 3, 1, 4, 1, 5 })
	if len(m1) == 4 { pass = pass + 1 }
	if m1[0] == 3 { pass = pass + 1 }
	if m1[1] == 4 { pass = pass + 1 }
	if m1[2] == 4 { pass = pass + 1 }
	if m1[3] == 5 { pass = pass + 1 }

	// PairwiseMaxInt — descending.
	var m2 []int = slices.PairwiseMaxInt(new(4) []int { 9, 5, 3, 1 })
	if m2[0] == 9 { pass = pass + 1 }
	if m2[2] == 3 { pass = pass + 1 }

	// PairwiseMaxInt — len < 2 → empty.
	var m3 []int = slices.PairwiseMaxInt(new(1) []int { 5 })
	if len(m3) == 0 { pass = pass + 1 }
	var m4 []int = slices.PairwiseMaxInt(new(0) []int {})
	if len(m4) == 0 { pass = pass + 1 }

	// PairwiseMaxInt — equal pair.
	var m5 []int = slices.PairwiseMaxInt(new(3) []int { 5, 5, 3 })
	if m5[0] == 5 { pass = pass + 1 }
	if m5[1] == 5 { pass = pass + 1 }

	// PairwiseSumInt of [1,2,3,4] = [3,5,7]; SumInts = 15 = SumInts(pairs)/something not invariant.
	// Instead: PairwiseSum length is always max(0, len-1).
	if len(slices.PairwiseSumInt(new(10) []int { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 })) == 9 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
