package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → "".
	var e []string = new(0) []string {}
	if slices.MedianString(e) == "" { pass = pass + 1 }

	// Single → itself.
	var s1 []string = new(1) []string { "alone" }
	if slices.MedianString(s1) == "alone" { pass = pass + 1 }

	// Odd, sorted.
	var s2 []string = new(3) []string { "a", "b", "c" }
	if slices.MedianString(s2) == "b" { pass = pass + 1 }

	// Odd, unsorted.
	var s3 []string = new(5) []string { "echo", "alpha", "charlie", "bravo", "delta" }
	if slices.MedianString(s3) == "charlie" { pass = pass + 1 }

	// Even, lower-middle.
	var s4 []string = new(4) []string { "a", "b", "c", "d" }
	if slices.MedianString(s4) == "b" { pass = pass + 1 }

	var s5 []string = new(6) []string { "f", "e", "d", "c", "b", "a" }
	// sorted: a,b,c,d,e,f; lower middle (index 2) = "c"
	if slices.MedianString(s5) == "c" { pass = pass + 1 }

	// Duplicates.
	var s6 []string = new(5) []string { "x", "x", "x", "y", "y" }
	if slices.MedianString(s6) == "x" { pass = pass + 1 }

	var s7 []string = new(7) []string { "b", "a", "a", "b", "c", "b", "a" }
	// sorted: a,a,a,b,b,b,c; middle (index 3) = "b"
	if slices.MedianString(s7) == "b" { pass = pass + 1 }

	// All same.
	var s8 []string = new(4) []string { "same", "same", "same", "same" }
	if slices.MedianString(s8) == "same" { pass = pass + 1 }

	// Doesn't mutate s.
	var s9 []string = new(4) []string { "d", "a", "c", "b" }
	var _r string = slices.MedianString(s9)
	if s9[0] == "d" { pass = pass + 1 }
	if s9[1] == "a" { pass = pass + 1 }
	if s9[2] == "c" { pass = pass + 1 }
	if s9[3] == "b" { pass = pass + 1 }

	// Cross-property: MedianString(s) == KthSmallestString(s, (n-1)/2).
	var s10 []string = new(5) []string { "delta", "alpha", "echo", "bravo", "charlie" }
	var s10b []string = new(5) []string { "delta", "alpha", "echo", "bravo", "charlie" }
	if slices.MedianString(s10) == slices.KthSmallestString(s10b, 2) { pass = pass + 1 }

	// Even n cross-property: == KthSmallestString(s, n/2 - 1).
	var s11 []string = new(4) []string { "d", "a", "c", "b" }
	var s11b []string = new(4) []string { "d", "a", "c", "b" }
	if slices.MedianString(s11) == slices.KthSmallestString(s11b, 1) { pass = pass + 1 }

	// Use case: median username in a sorted-list audit.
	var users []string = new(5) []string { "tom", "alice", "carol", "bob", "dave" }
	// sorted: alice, bob, carol, dave, tom; median = carol
	if slices.MedianString(users) == "carol" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
