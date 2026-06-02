package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Int — at least one candidate present.
	var a []int = new(5) []int { 1, 2, 3, 4, 5 }
	var cand1 []int = new(2) []int { 3, 99 }
	if slices.ContainsAnyInt(a, cand1) { pass = pass + 1 }

	// All candidates absent.
	var a2 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var cand2 []int = new(3) []int { 100, 200, 300 }
	if !slices.ContainsAnyInt(a2, cand2) { pass = pass + 1 }

	// Empty s, non-empty candidates → false.
	var empty []int = new(0) []int {}
	var cand3 []int = new(2) []int { 1, 2 }
	if !slices.ContainsAnyInt(empty, cand3) { pass = pass + 1 }

	// Non-empty s, empty candidates → false.
	var a3 []int = new(3) []int { 1, 2, 3 }
	var emptyCand []int = new(0) []int {}
	if !slices.ContainsAnyInt(a3, emptyCand) { pass = pass + 1 }

	// Both empty → false.
	var e1 []int = new(0) []int {}
	var e2 []int = new(0) []int {}
	if !slices.ContainsAnyInt(e1, e2) { pass = pass + 1 }

	// Single overlap.
	var a4 []int = new(3) []int { 10, 20, 30 }
	var cand4 []int = new(1) []int { 30 }
	if slices.ContainsAnyInt(a4, cand4) { pass = pass + 1 }

	// First-candidate-found short-circuit (functional correctness).
	var a5 []int = new(4) []int { 5, 6, 7, 8 }
	var cand5 []int = new(3) []int { 99, 6, 100 }
	if slices.ContainsAnyInt(a5, cand5) { pass = pass + 1 }

	// String parallel suite.
	var s []string = new(3) []string { "apple", "banana", "cherry" }
	var sc1 []string = new(2) []string { "fig", "banana" }
	if slices.ContainsAnyString(s, sc1) { pass = pass + 1 }

	var s2 []string = new(3) []string { "apple", "banana", "cherry" }
	var sc2 []string = new(2) []string { "fig", "grape" }
	if !slices.ContainsAnyString(s2, sc2) { pass = pass + 1 }

	var se []string = new(0) []string {}
	var sce []string = new(0) []string {}
	if !slices.ContainsAnyString(se, sce) { pass = pass + 1 }

	// Strings: empty value as a candidate.
	var s3 []string = new(3) []string { "a", "", "b" }
	var sc3 []string = new(1) []string { "" }
	if slices.ContainsAnyString(s3, sc3) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
