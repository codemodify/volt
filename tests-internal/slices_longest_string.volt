package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []string = new(0) []string {}
	if slices.LongestString(e) == "" { pass = pass + 1 }
	var e2 []string = new(0) []string {}
	if slices.ShortestString(e2) == "" { pass = pass + 1 }
	var e3 []string = new(0) []string {}
	if slices.MaxLenString(e3) == 0 { pass = pass + 1 }
	var e4 []string = new(0) []string {}
	if slices.MinLenString(e4) == 0 { pass = pass + 1 }

	// Single.
	var s1 []string = new(1) []string { "hello" }
	if slices.LongestString(s1) == "hello" { pass = pass + 1 }
	var s1b []string = new(1) []string { "hello" }
	if slices.ShortestString(s1b) == "hello" { pass = pass + 1 }
	var s1c []string = new(1) []string { "hello" }
	if slices.MaxLenString(s1c) == 5 { pass = pass + 1 }
	var s1d []string = new(1) []string { "hello" }
	if slices.MinLenString(s1d) == 5 { pass = pass + 1 }

	// Clear winner.
	var s2 []string = new(4) []string { "a", "bb", "ccc", "dddd" }
	if slices.LongestString(s2) == "dddd" { pass = pass + 1 }
	var s2b []string = new(4) []string { "a", "bb", "ccc", "dddd" }
	if slices.ShortestString(s2b) == "a" { pass = pass + 1 }
	var s2c []string = new(4) []string { "a", "bb", "ccc", "dddd" }
	if slices.MaxLenString(s2c) == 4 { pass = pass + 1 }
	var s2d []string = new(4) []string { "a", "bb", "ccc", "dddd" }
	if slices.MinLenString(s2d) == 1 { pass = pass + 1 }

	// Tie → first wins.
	var s3 []string = new(3) []string { "abc", "xyz", "qrs" }
	if slices.LongestString(s3) == "abc" { pass = pass + 1 }
	var s3b []string = new(3) []string { "abc", "xyz", "qrs" }
	if slices.ShortestString(s3b) == "abc" { pass = pass + 1 }

	// All same length.
	var s4 []string = new(4) []string { "aa", "bb", "cc", "dd" }
	if slices.MaxLenString(s4) == 2 { pass = pass + 1 }
	var s4b []string = new(4) []string { "aa", "bb", "cc", "dd" }
	if slices.MinLenString(s4b) == 2 { pass = pass + 1 }

	// Empty strings present.
	var s5 []string = new(3) []string { "", "x", "yz" }
	if slices.MinLenString(s5) == 0 { pass = pass + 1 }
	var s5b []string = new(3) []string { "", "x", "yz" }
	if slices.ShortestString(s5b) == "" { pass = pass + 1 }
	var s5c []string = new(3) []string { "", "x", "yz" }
	if slices.MaxLenString(s5c) == 2 { pass = pass + 1 }
	var s5d []string = new(3) []string { "", "x", "yz" }
	if slices.LongestString(s5d) == "yz" { pass = pass + 1 }

	// Doesn't mutate.
	var s6 []string = new(3) []string { "alpha", "bravo", "charlie" }
	var _r string = slices.LongestString(s6)
	if s6[0] == "alpha" { pass = pass + 1 }
	if s6[1] == "bravo" { pass = pass + 1 }
	if s6[2] == "charlie" { pass = pass + 1 }

	// Cross-property: MaxLen >= MinLen.
	var s7 []string = new(5) []string { "a", "bb", "ccc", "dddd", "eeeee" }
	var s7b []string = new(5) []string { "a", "bb", "ccc", "dddd", "eeeee" }
	if slices.MaxLenString(s7) >= slices.MinLenString(s7b) { pass = pass + 1 }

	// Cross-property: len(LongestString) == MaxLenString.
	var s8 []string = new(4) []string { "x", "yy", "zzz", "wwww" }
	var s8b []string = new(4) []string { "x", "yy", "zzz", "wwww" }
	if len(slices.LongestString(s8)) == slices.MaxLenString(s8b) { pass = pass + 1 }

	// Table column-width use case.
	var col []string = new(5) []string { "Name", "Alice", "Bob", "Christopher", "D" }
	if slices.MaxLenString(col) == 11 { pass = pass + 1 }   // "Christopher" = 11

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
