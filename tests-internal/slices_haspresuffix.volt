package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	var s []int = new(5) []int { 1, 2, 3, 4, 5 }

	// HasPrefixInts — match.
	var p1 []int = new(3) []int { 1, 2, 3 }
	if slices.HasPrefixInts(s, p1) { pass = pass + 1 }

	// HasPrefixInts — mismatch.
	var p2 []int = new(3) []int { 1, 2, 9 }
	if !slices.HasPrefixInts(s, p2) { pass = pass + 1 }

	// HasPrefixInts — equal-length match.
	var pFull []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.HasPrefixInts(s, pFull) { pass = pass + 1 }

	// HasPrefixInts — empty prefix always matches.
	var pEmpty []int = new(0) []int {}
	if slices.HasPrefixInts(s, pEmpty) { pass = pass + 1 }

	// HasPrefixInts — prefix longer than s → false.
	var pTooLong []int = new(6) []int { 1, 2, 3, 4, 5, 6 }
	if !slices.HasPrefixInts(s, pTooLong) { pass = pass + 1 }

	// HasPrefixInts — empty s, empty prefix.
	var emp []int = new(0) []int {}
	if slices.HasPrefixInts(emp, pEmpty) { pass = pass + 1 }

	// HasPrefixInts — empty s, non-empty prefix.
	if !slices.HasPrefixInts(emp, p1) { pass = pass + 1 }

	// HasSuffixInts — match.
	var sx1 []int = new(2) []int { 4, 5 }
	if slices.HasSuffixInts(s, sx1) { pass = pass + 1 }

	// HasSuffixInts — mismatch.
	var sx2 []int = new(2) []int { 3, 5 }
	if !slices.HasSuffixInts(s, sx2) { pass = pass + 1 }

	// HasSuffixInts — empty suffix matches.
	if slices.HasSuffixInts(s, pEmpty) { pass = pass + 1 }

	// HasSuffixInts — equal-length match.
	if slices.HasSuffixInts(s, pFull) { pass = pass + 1 }

	// HasSuffixInts — too-long suffix → false.
	if !slices.HasSuffixInts(s, pTooLong) { pass = pass + 1 }

	// HasPrefixStrings — basic.
	var ss []string = new(4) []string { "alpha", "beta", "gamma", "delta" }
	var sp1 []string = new(2) []string { "alpha", "beta" }
	if slices.HasPrefixStrings(ss, sp1) { pass = pass + 1 }

	// HasPrefixStrings — mismatch.
	var sp2 []string = new(2) []string { "alpha", "zeta" }
	if !slices.HasPrefixStrings(ss, sp2) { pass = pass + 1 }

	// HasSuffixStrings — basic.
	var sx3 []string = new(2) []string { "gamma", "delta" }
	if slices.HasSuffixStrings(ss, sx3) { pass = pass + 1 }

	// HasSuffixStrings — mismatch.
	var sx4 []string = new(2) []string { "beta", "delta" }
	if !slices.HasSuffixStrings(ss, sx4) { pass = pass + 1 }

	// Empty prefix/suffix string-slices.
	var spe []string = new(0) []string {}
	if slices.HasPrefixStrings(ss, spe) { pass = pass + 1 }
	if slices.HasSuffixStrings(ss, spe) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
