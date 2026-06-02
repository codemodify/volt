package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty / single → false.
	var e []int = new(0) []int {}
	if !slices.HasDuplicatesInt(e) { pass = pass + 1 }
	var e2 []string = new(0) []string {}
	if !slices.HasDuplicatesString(e2) { pass = pass + 1 }
	var s1 []int = new(1) []int { 42 }
	if !slices.HasDuplicatesInt(s1) { pass = pass + 1 }
	var s2 []string = new(1) []string { "alice" }
	if !slices.HasDuplicatesString(s2) { pass = pass + 1 }

	// All unique.
	var s3 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if !slices.HasDuplicatesInt(s3) { pass = pass + 1 }
	var s4 []string = new(3) []string { "a", "b", "c" }
	if !slices.HasDuplicatesString(s4) { pass = pass + 1 }

	// One duplicate at end.
	var s5 []int = new(5) []int { 1, 2, 3, 4, 1 }
	if slices.HasDuplicatesInt(s5) { pass = pass + 1 }

	// One duplicate adjacent.
	var s6 []int = new(5) []int { 1, 2, 2, 3, 4 }
	if slices.HasDuplicatesInt(s6) { pass = pass + 1 }

	// All same.
	var s7 []int = new(4) []int { 7, 7, 7, 7 }
	if slices.HasDuplicatesInt(s7) { pass = pass + 1 }
	var s8 []string = new(4) []string { "x", "x", "x", "x" }
	if slices.HasDuplicatesString(s8) { pass = pass + 1 }

	// String duplicates.
	var s9 []string = new(5) []string { "alpha", "bravo", "charlie", "alpha", "delta" }
	if slices.HasDuplicatesString(s9) { pass = pass + 1 }
	var s10 []string = new(4) []string { "a", "b", "c", "d" }
	if !slices.HasDuplicatesString(s10) { pass = pass + 1 }

	// Negative numbers.
	var s11 []int = new(4) []int { -1, -2, -3, -1 }
	if slices.HasDuplicatesInt(s11) { pass = pass + 1 }

	// Zeros.
	var s12 []int = new(3) []int { 0, 1, 0 }
	if slices.HasDuplicatesInt(s12) { pass = pass + 1 }

	// Cross-property: HasDuplicates iff len(Unique) < len(s).
	var s13 []int = new(5) []int { 1, 2, 2, 3, 4 }
	var s13b []int = new(5) []int { 1, 2, 2, 3, 4 }
	var u []int = slices.UniqueInts(s13b)
	var hasDup bool = slices.HasDuplicatesInt(s13)
	if hasDup == (len(u) < 5) { pass = pass + 1 }

	var s14 []int = new(4) []int { 1, 2, 3, 4 }
	var s14b []int = new(4) []int { 1, 2, 3, 4 }
	var u2 []int = slices.UniqueInts(s14b)
	var hasDup2 bool = slices.HasDuplicatesInt(s14)
	if hasDup2 == (len(u2) < 4) { pass = pass + 1 }

	// Input validation use case: distinct user IDs.
	var userIds []int = new(4) []int { 100, 200, 300, 400 }
	if !slices.HasDuplicatesInt(userIds) { pass = pass + 1 }
	var badIds []int = new(4) []int { 100, 200, 100, 400 }
	if slices.HasDuplicatesInt(badIds) { pass = pass + 1 }

	// Distinct usernames.
	var usernames []string = new(3) []string { "alice", "bob", "carol" }
	if !slices.HasDuplicatesString(usernames) { pass = pass + 1 }
	var dupNames []string = new(3) []string { "alice", "bob", "alice" }
	if slices.HasDuplicatesString(dupNames) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
