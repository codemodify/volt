package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	if slices.IndexNthInt(e, 5, 0) == -1 { pass = pass + 1 }

	// No occurrence.
	var s1 []int = new(3) []int { 1, 2, 3 }
	if slices.IndexNthInt(s1, 99, 0) == -1 { pass = pass + 1 }

	// First occurrence (n=0).
	var s2 []int = new(5) []int { 7, 3, 7, 4, 7 }
	if slices.IndexNthInt(s2, 7, 0) == 0 { pass = pass + 1 }
	var s2b []int = new(5) []int { 7, 3, 7, 4, 7 }
	if slices.IndexNthInt(s2b, 7, 1) == 2 { pass = pass + 1 }
	var s2c []int = new(5) []int { 7, 3, 7, 4, 7 }
	if slices.IndexNthInt(s2c, 7, 2) == 4 { pass = pass + 1 }

	// Out of range n.
	var s3 []int = new(5) []int { 7, 3, 7, 4, 7 }
	if slices.IndexNthInt(s3, 7, 3) == -1 { pass = pass + 1 }
	var s3b []int = new(5) []int { 7, 3, 7, 4, 7 }
	if slices.IndexNthInt(s3b, 7, 99) == -1 { pass = pass + 1 }

	// n < 0.
	var s4 []int = new(3) []int { 1, 2, 1 }
	if slices.IndexNthInt(s4, 1, -1) == -1 { pass = pass + 1 }

	// Single occurrence.
	var s5 []int = new(4) []int { 1, 2, 99, 4 }
	if slices.IndexNthInt(s5, 99, 0) == 2 { pass = pass + 1 }
	var s5b []int = new(4) []int { 1, 2, 99, 4 }
	if slices.IndexNthInt(s5b, 99, 1) == -1 { pass = pass + 1 }

	// All same.
	var s6 []int = new(4) []int { 5, 5, 5, 5 }
	if slices.IndexNthInt(s6, 5, 0) == 0 { pass = pass + 1 }
	var s6b []int = new(4) []int { 5, 5, 5, 5 }
	if slices.IndexNthInt(s6b, 5, 3) == 3 { pass = pass + 1 }
	var s6c []int = new(4) []int { 5, 5, 5, 5 }
	if slices.IndexNthInt(s6c, 5, 4) == -1 { pass = pass + 1 }

	// String variant.
	var ss []string = new(5) []string { "x", "y", "x", "z", "x" }
	if slices.IndexNthString(ss, "x", 0) == 0 { pass = pass + 1 }
	var ss2 []string = new(5) []string { "x", "y", "x", "z", "x" }
	if slices.IndexNthString(ss2, "x", 1) == 2 { pass = pass + 1 }
	var ss3 []string = new(5) []string { "x", "y", "x", "z", "x" }
	if slices.IndexNthString(ss3, "x", 2) == 4 { pass = pass + 1 }
	var ss4 []string = new(5) []string { "x", "y", "x", "z", "x" }
	if slices.IndexNthString(ss4, "x", 3) == -1 { pass = pass + 1 }

	// Cross-property: IndexNthInt(s, v, n) == IndicesOfInt(s, v)[n] when valid.
	var s7 []int = new(6) []int { 1, 7, 2, 7, 3, 7 }
	var s7b []int = new(6) []int { 1, 7, 2, 7, 3, 7 }
	var idxs []int = slices.IndicesOfInt(s7, 7)
	if slices.IndexNthInt(s7b, 7, 1) == idxs[1] { pass = pass + 1 }

	// Use case: find the second tab separator.
	var data []int = new(8) []int { 65, 9, 66, 9, 67, 9, 68, 9 }
	// 9 = tab byte; positions 1, 3, 5, 7
	if slices.IndexNthInt(data, 9, 1) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
