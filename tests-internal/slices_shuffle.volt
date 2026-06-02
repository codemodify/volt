package main
import "log"
import "slices"

// Positive test: slices.ShuffleInts / ShuffleStrings — Fisher-Yates
// shuffle using crypto-strong randomness. Verify multiset
// preservation + at-least-one-different-ordering across draws.

fun main() int {
	var pass int = 0

	// Multiset preservation: shuffle preserves all elements.
	var a []int = new(8) []int{1, 2, 3, 4, 5, 6, 7, 8}
	a = slices.ShuffleInts(a)
	if len(a) == 8 { pass = pass + 1 }
	// Each element from 1..8 must still be present.
	var allPresent bool = true
	for v := 1; v <= 8; v++ {
		if !slices.ContainsInt(a, v) { allPresent = false }
	}
	if allPresent { pass = pass + 1 }
	// Sum should equal 1+2+...+8 = 36.
	if slices.SumInts(a) == 36 { pass = pass + 1 }

	// Distribution: shuffling a 10-element slice 20 times should
	// produce at least one non-identity ordering. (P(all 20 are
	// identity) = (1/10!)^20 — astronomically small.)
	var anyDiff bool = false
	for trial := 0; trial < 20; trial++ {
		var s []int = new(10) []int{0, 1, 2, 3, 4, 5, 6, 7, 8, 9}
		s = slices.ShuffleInts(s)
		for i := 0; i < 10; i++ {
			if s[i] != i { anyDiff = true }
		}
	}
	if anyDiff { pass = pass + 1 }

	// Empty slice → empty.
	var e []int = new(0) []int{}
	e = slices.ShuffleInts(e)
	if len(e) == 0 { pass = pass + 1 }

	// Single-element slice unchanged.
	var one []int = new(1) []int{42}
	one = slices.ShuffleInts(one)
	if len(one) == 1 { pass = pass + 1 }
	if one[0] == 42 { pass = pass + 1 }

	// ShuffleStrings: multiset preservation.
	var s1 []string = new(4) []string{"a", "b", "c", "d"}
	s1 = slices.ShuffleStrings(s1)
	if len(s1) == 4 { pass = pass + 1 }
	var allFour bool = true
	if !slices.ContainsString(s1, "a") { allFour = false }
	if !slices.ContainsString(s1, "b") { allFour = false }
	if !slices.ContainsString(s1, "c") { allFour = false }
	if !slices.ContainsString(s1, "d") { allFour = false }
	if allFour { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 9 { ret 42 }
	ret 0
}
