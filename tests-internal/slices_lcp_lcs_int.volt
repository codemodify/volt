package main
import "log"
import "slices"

// Positive test: slices.LongestCommonPrefixInt + slices.LongestCommonSuffixInt.

fun main() int {
	var pass int = 0

	// LCP — basic.
	if slices.LongestCommonPrefixInt(new(4) []int { 1, 2, 3, 4 }, new(4) []int { 1, 2, 5, 6 }) == 2 { pass = pass + 1 }
	if slices.LongestCommonPrefixInt(new(3) []int { 1, 2, 3 }, new(3) []int { 1, 2, 3 }) == 3 { pass = pass + 1 }

	// LCP — disagreement on first.
	if slices.LongestCommonPrefixInt(new(3) []int { 1, 2, 3 }, new(3) []int { 9, 8, 7 }) == 0 { pass = pass + 1 }

	// LCP — empty.
	if slices.LongestCommonPrefixInt(new(0) []int {}, new(3) []int { 1, 2, 3 }) == 0 { pass = pass + 1 }
	if slices.LongestCommonPrefixInt(new(3) []int { 1, 2, 3 }, new(0) []int {}) == 0 { pass = pass + 1 }
	if slices.LongestCommonPrefixInt(new(0) []int {}, new(0) []int {}) == 0 { pass = pass + 1 }

	// LCP — prefix-of relationship.
	if slices.LongestCommonPrefixInt(new(2) []int { 1, 2 }, new(5) []int { 1, 2, 3, 4, 5 }) == 2 { pass = pass + 1 }
	if slices.LongestCommonPrefixInt(new(5) []int { 1, 2, 3, 4, 5 }, new(2) []int { 1, 2 }) == 2 { pass = pass + 1 }

	// LCS (suffix) — basic.
	if slices.LongestCommonSuffixInt(new(5) []int { 1, 2, 3, 4, 5 }, new(5) []int { 9, 8, 3, 4, 5 }) == 3 { pass = pass + 1 }

	// LCS — full match.
	if slices.LongestCommonSuffixInt(new(3) []int { 1, 2, 3 }, new(3) []int { 1, 2, 3 }) == 3 { pass = pass + 1 }

	// LCS — disagreement on last.
	if slices.LongestCommonSuffixInt(new(3) []int { 1, 2, 3 }, new(3) []int { 1, 2, 9 }) == 0 { pass = pass + 1 }

	// LCS — empty.
	if slices.LongestCommonSuffixInt(new(0) []int {}, new(3) []int { 1, 2, 3 }) == 0 { pass = pass + 1 }
	if slices.LongestCommonSuffixInt(new(0) []int {}, new(0) []int {}) == 0 { pass = pass + 1 }

	// LCS — suffix-of relationship.
	if slices.LongestCommonSuffixInt(new(2) []int { 4, 5 }, new(5) []int { 1, 2, 3, 4, 5 }) == 2 { pass = pass + 1 }

	// LCS — same content, different lengths.
	if slices.LongestCommonSuffixInt(new(4) []int { 7, 1, 2, 3 }, new(2) []int { 2, 3 }) == 2 { pass = pass + 1 }

	// LCP + LCS sanity: equal slices → both == len.
	var same []int = new(4) []int { 1, 2, 3, 4 }
	if slices.LongestCommonPrefixInt(same, same) == 4 { pass = pass + 1 }
	if slices.LongestCommonSuffixInt(same, same) == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
