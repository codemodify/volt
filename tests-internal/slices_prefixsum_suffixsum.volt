package main
import "log"
import "slices"

// Positive test: slices.PrefixSumInt + slices.SuffixSumInt.

fun main() int {
	var pass int = 0

	// PrefixSumInt — basic.
	var p1 []int = slices.PrefixSumInt(new(5) []int { 1, 2, 3, 4, 5 })
	if len(p1) == 5 { pass = pass + 1 }
	if p1[0] == 1 { pass = pass + 1 }
	if p1[1] == 3 { pass = pass + 1 }
	if p1[2] == 6 { pass = pass + 1 }
	if p1[3] == 10 { pass = pass + 1 }
	if p1[4] == 15 { pass = pass + 1 }

	// PrefixSumInt — all-zeros.
	var p2 []int = slices.PrefixSumInt(new(3) []int { 0, 0, 0 })
	if p2[0] == 0 { pass = pass + 1 }
	if p2[2] == 0 { pass = pass + 1 }

	// PrefixSumInt — empty.
	var p3 []int = slices.PrefixSumInt(new(0) []int {})
	if len(p3) == 0 { pass = pass + 1 }

	// PrefixSumInt — single.
	var p4 []int = slices.PrefixSumInt(new(1) []int { 42 })
	if p4[0] == 42 { pass = pass + 1 }

	// PrefixSumInt — negatives.
	var p5 []int = slices.PrefixSumInt(new(4) []int { -1, -2, -3, -4 })
	if p5[0] == -1 { pass = pass + 1 }
	if p5[3] == -10 { pass = pass + 1 }

	// SuffixSumInt — basic.
	var s1 []int = slices.SuffixSumInt(new(5) []int { 1, 2, 3, 4, 5 })
	if len(s1) == 5 { pass = pass + 1 }
	if s1[0] == 15 { pass = pass + 1 }
	if s1[1] == 14 { pass = pass + 1 }
	if s1[2] == 12 { pass = pass + 1 }
	if s1[3] == 9 { pass = pass + 1 }
	if s1[4] == 5 { pass = pass + 1 }

	// SuffixSumInt — empty.
	var s2 []int = slices.SuffixSumInt(new(0) []int {})
	if len(s2) == 0 { pass = pass + 1 }

	// SuffixSumInt — single.
	var s3 []int = slices.SuffixSumInt(new(1) []int { 42 })
	if s3[0] == 42 { pass = pass + 1 }

	// PrefixSum[last] == SuffixSum[0] (both == total).
	var sample []int = new(4) []int { 10, 20, 30, 40 }
	var pp []int = slices.PrefixSumInt(sample)
	var ss []int = slices.SuffixSumInt(sample)
	if pp[3] == ss[0] { pass = pass + 1 }
	if pp[3] == 100 { pass = pass + 1 }

	// Range sum via prefix: s[1..3] = pp[3] - pp[0] = 100 - 10 = 90.
	if pp[3] - pp[0] == 90 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
