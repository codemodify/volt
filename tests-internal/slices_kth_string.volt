package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → "".
	var e []string = new(0) []string {}
	if slices.KthSmallestString(e, 0) == "" { pass = pass + 1 }
	var e2 []string = new(0) []string {}
	if slices.KthLargestString(e2, 0) == "" { pass = pass + 1 }

	// Single element.
	var s1 []string = new(1) []string { "alice" }
	if slices.KthSmallestString(s1, 0) == "alice" { pass = pass + 1 }
	var s1b []string = new(1) []string { "alice" }
	if slices.KthLargestString(s1b, 0) == "alice" { pass = pass + 1 }

	// Sorted ascending lex.
	var s2 []string = new(5) []string { "a", "b", "c", "d", "e" }
	if slices.KthSmallestString(s2, 0) == "a" { pass = pass + 1 }
	var s2b []string = new(5) []string { "a", "b", "c", "d", "e" }
	if slices.KthSmallestString(s2b, 2) == "c" { pass = pass + 1 }
	var s2c []string = new(5) []string { "a", "b", "c", "d", "e" }
	if slices.KthSmallestString(s2c, 4) == "e" { pass = pass + 1 }

	// k=0 is max for KthLargest.
	var s3 []string = new(5) []string { "a", "b", "c", "d", "e" }
	if slices.KthLargestString(s3, 0) == "e" { pass = pass + 1 }
	var s3b []string = new(5) []string { "a", "b", "c", "d", "e" }
	if slices.KthLargestString(s3b, 1) == "d" { pass = pass + 1 }   // silver
	var s3c []string = new(5) []string { "a", "b", "c", "d", "e" }
	if slices.KthLargestString(s3c, 4) == "a" { pass = pass + 1 }

	// Unsorted input.
	var s4 []string = new(5) []string { "delta", "alpha", "echo", "bravo", "charlie" }
	if slices.KthSmallestString(s4, 0) == "alpha" { pass = pass + 1 }
	var s4b []string = new(5) []string { "delta", "alpha", "echo", "bravo", "charlie" }
	if slices.KthSmallestString(s4b, 2) == "charlie" { pass = pass + 1 }
	var s4c []string = new(5) []string { "delta", "alpha", "echo", "bravo", "charlie" }
	if slices.KthLargestString(s4c, 0) == "echo" { pass = pass + 1 }

	// Duplicates.
	var s5 []string = new(6) []string { "b", "a", "b", "c", "a", "b" }
	// sorted: a,a,b,b,b,c
	if slices.KthSmallestString(s5, 0) == "a" { pass = pass + 1 }
	var s5b []string = new(6) []string { "b", "a", "b", "c", "a", "b" }
	if slices.KthSmallestString(s5b, 2) == "b" { pass = pass + 1 }
	var s5c []string = new(6) []string { "b", "a", "b", "c", "a", "b" }
	if slices.KthSmallestString(s5c, 5) == "c" { pass = pass + 1 }

	// k out of range → "".
	var s6 []string = new(3) []string { "x", "y", "z" }
	if slices.KthSmallestString(s6, -1) == "" { pass = pass + 1 }
	var s6b []string = new(3) []string { "x", "y", "z" }
	if slices.KthSmallestString(s6b, 5) == "" { pass = pass + 1 }
	var s6c []string = new(3) []string { "x", "y", "z" }
	if slices.KthLargestString(s6c, 99) == "" { pass = pass + 1 }

	// Doesn't mutate s.
	var s7 []string = new(4) []string { "d", "a", "c", "b" }
	var _r string = slices.KthSmallestString(s7, 1)
	if s7[0] == "d" { pass = pass + 1 }
	if s7[1] == "a" { pass = pass + 1 }
	if s7[2] == "c" { pass = pass + 1 }
	if s7[3] == "b" { pass = pass + 1 }

	// Cross-property: KthSmallest(s, k) == KthLargest(s, n-1-k).
	var s8 []string = new(5) []string { "delta", "alpha", "echo", "bravo", "charlie" }
	var s8b []string = new(5) []string { "delta", "alpha", "echo", "bravo", "charlie" }
	var sm string = slices.KthSmallestString(s8, 1)
	var lg string = slices.KthLargestString(s8b, 3)
	if sm == lg { pass = pass + 1 }

	// "Second-newest log file" use case (lex sort approximates timestamp prefix).
	var logs []string = new(4) []string { "2026-05-15.log", "2026-05-28.log", "2026-05-20.log", "2026-05-10.log" }
	if slices.KthLargestString(logs, 1) == "2026-05-20.log" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
