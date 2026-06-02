package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → -1.
	var e []string = new(0) []string {}
	if slices.IndexOfLongestString(e) == -1 { pass = pass + 1 }
	var e2 []string = new(0) []string {}
	if slices.IndexOfShortestString(e2) == -1 { pass = pass + 1 }

	// Single → 0.
	var s1 []string = new(1) []string { "hello" }
	if slices.IndexOfLongestString(s1) == 0 { pass = pass + 1 }
	var s1b []string = new(1) []string { "hello" }
	if slices.IndexOfShortestString(s1b) == 0 { pass = pass + 1 }

	// Clear winner at end.
	var s2 []string = new(4) []string { "a", "bb", "ccc", "dddd" }
	if slices.IndexOfLongestString(s2) == 3 { pass = pass + 1 }
	var s2b []string = new(4) []string { "a", "bb", "ccc", "dddd" }
	if slices.IndexOfShortestString(s2b) == 0 { pass = pass + 1 }

	// Clear winner at start.
	var s3 []string = new(4) []string { "dddd", "ccc", "bb", "a" }
	if slices.IndexOfLongestString(s3) == 0 { pass = pass + 1 }
	var s3b []string = new(4) []string { "dddd", "ccc", "bb", "a" }
	if slices.IndexOfShortestString(s3b) == 3 { pass = pass + 1 }

	// Tie → earliest.
	var s4 []string = new(4) []string { "xx", "yy", "z", "ww" }   // ties at 2 chars: 0,1,3
	if slices.IndexOfLongestString(s4) == 0 { pass = pass + 1 }
	var s4b []string = new(3) []string { "a", "b", "c" }   // all same length
	if slices.IndexOfShortestString(s4b) == 0 { pass = pass + 1 }

	// All same length.
	var s5 []string = new(4) []string { "aa", "bb", "cc", "dd" }
	if slices.IndexOfLongestString(s5) == 0 { pass = pass + 1 }
	var s5b []string = new(4) []string { "aa", "bb", "cc", "dd" }
	if slices.IndexOfShortestString(s5b) == 0 { pass = pass + 1 }

	// Empty strings present.
	var s6 []string = new(3) []string { "", "longest", "" }
	if slices.IndexOfLongestString(s6) == 1 { pass = pass + 1 }
	var s6b []string = new(3) []string { "", "longest", "" }
	if slices.IndexOfShortestString(s6b) == 0 { pass = pass + 1 }

	// Cross-property: s[IndexOfLongest] == LongestString.
	var s7 []string = new(5) []string { "alpha", "br", "charlie", "d", "echo" }
	var s7b []string = new(5) []string { "alpha", "br", "charlie", "d", "echo" }
	var idxL int = slices.IndexOfLongestString(s7)
	if s7b[idxL] == slices.LongestString(s7) { pass = pass + 1 }

	// Cross-property: s[IndexOfShortest] == ShortestString.
	var s8 []string = new(5) []string { "alpha", "br", "charlie", "d", "echo" }
	var s8b []string = new(5) []string { "alpha", "br", "charlie", "d", "echo" }
	var idxS int = slices.IndexOfShortestString(s8)
	if s8b[idxS] == slices.ShortestString(s8) { pass = pass + 1 }

	// Doesn't mutate.
	var s9 []string = new(3) []string { "x", "yyy", "zz" }
	var _i int = slices.IndexOfLongestString(s9)
	if s9[0] == "x" { pass = pass + 1 }
	if s9[1] == "yyy" { pass = pass + 1 }
	if s9[2] == "zz" { pass = pass + 1 }

	// Use case: pair the longest filename with its index.
	var files []string = new(4) []string { "a.txt", "report-2026-may.txt", "log", "settings.json" }
	if slices.IndexOfLongestString(files) == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
