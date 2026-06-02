package main
import "log"
import "slices"

// Positive test: slices.PairwiseMinInt + slices.PairwiseAvgInt.

fun main() int {
	var pass int = 0

	// PairwiseMinInt — basic.
	var m1 []int = slices.PairwiseMinInt(new(5) []int { 3, 1, 4, 1, 5 })
	if len(m1) == 4 { pass = pass + 1 }
	if m1[0] == 1 { pass = pass + 1 }
	if m1[1] == 1 { pass = pass + 1 }
	if m1[2] == 1 { pass = pass + 1 }
	if m1[3] == 1 { pass = pass + 1 }

	// PairwiseMinInt — ascending.
	var m2 []int = slices.PairwiseMinInt(new(4) []int { 1, 2, 3, 4 })
	if m2[0] == 1 { pass = pass + 1 }
	if m2[2] == 3 { pass = pass + 1 }

	// PairwiseMinInt — descending.
	var m3 []int = slices.PairwiseMinInt(new(4) []int { 9, 5, 3, 1 })
	if m3[0] == 5 { pass = pass + 1 }
	if m3[2] == 1 { pass = pass + 1 }

	// PairwiseMinInt — len < 2.
	var m4 []int = slices.PairwiseMinInt(new(1) []int { 5 })
	if len(m4) == 0 { pass = pass + 1 }
	var m5 []int = slices.PairwiseMinInt(new(0) []int {})
	if len(m5) == 0 { pass = pass + 1 }

	// PairwiseMinInt — equal pair.
	var m6 []int = slices.PairwiseMinInt(new(3) []int { 5, 5, 3 })
	if m6[0] == 5 { pass = pass + 1 }
	if m6[1] == 3 { pass = pass + 1 }

	// PairwiseAvgInt — basic.
	var a1 []int = slices.PairwiseAvgInt(new(5) []int { 1, 3, 5, 7, 9 })
	if len(a1) == 4 { pass = pass + 1 }
	if a1[0] == 2 { pass = pass + 1 }     // (1+3)/2
	if a1[1] == 4 { pass = pass + 1 }
	if a1[2] == 6 { pass = pass + 1 }
	if a1[3] == 8 { pass = pass + 1 }

	// PairwiseAvgInt — equal pair.
	var a2 []int = slices.PairwiseAvgInt(new(3) []int { 7, 7, 7 })
	if a2[0] == 7 { pass = pass + 1 }
	if a2[1] == 7 { pass = pass + 1 }

	// PairwiseAvgInt — len < 2.
	var a3 []int = slices.PairwiseAvgInt(new(0) []int {})
	if len(a3) == 0 { pass = pass + 1 }

	// PairwiseAvgInt — large operands (overflow-safe).
	var a4 []int = slices.PairwiseAvgInt(new(2) []int { 9223372036854775806, 9223372036854775804 })
	if a4[0] == 9223372036854775805 { pass = pass + 1 }

	// Identity: Min[i] <= Avg[i] <= Max[i].
	var src []int = new(4) []int { 1, 5, 3, 9 }
	var pmin []int = slices.PairwiseMinInt(src)
	var pavg []int = slices.PairwiseAvgInt(src)
	var pmax []int = slices.PairwiseMaxInt(src)
	if pmin[0] <= pavg[0] { pass = pass + 1 }
	if pavg[0] <= pmax[0] { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
