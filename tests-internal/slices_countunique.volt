package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// All unique.
	var a []int = new(4) []int { 1, 2, 3, 4 }
	if slices.CountUniqueInt(a) == 4 { pass = pass + 1 }

	// All same → 1.
	var b []int = new(5) []int { 7, 7, 7, 7, 7 }
	if slices.CountUniqueInt(b) == 1 { pass = pass + 1 }

	// Mixed.
	var c []int = new(6) []int { 1, 2, 1, 3, 2, 1 }
	if slices.CountUniqueInt(c) == 3 { pass = pass + 1 }

	// Empty.
	var empty []int = new(0) []int {}
	if slices.CountUniqueInt(empty) == 0 { pass = pass + 1 }

	// Single.
	var solo []int = new(1) []int { 42 }
	if slices.CountUniqueInt(solo) == 1 { pass = pass + 1 }

	// Negatives + zero.
	var d []int = new(5) []int { -1, 0, -1, 1, 0 }
	if slices.CountUniqueInt(d) == 3 { pass = pass + 1 }

	// CountUniqueString — basic.
	var sa []string = new(5) []string { "apple", "banana", "apple", "cherry", "banana" }
	if slices.CountUniqueString(sa) == 3 { pass = pass + 1 }

	// CountUniqueString — all unique.
	var sb []string = new(3) []string { "x", "y", "z" }
	if slices.CountUniqueString(sb) == 3 { pass = pass + 1 }

	// CountUniqueString — all same.
	var sc []string = new(4) []string { "same", "same", "same", "same" }
	if slices.CountUniqueString(sc) == 1 { pass = pass + 1 }

	// CountUniqueString — empty.
	var se []string = new(0) []string {}
	if slices.CountUniqueString(se) == 0 { pass = pass + 1 }

	// CountUniqueString — empty-string treated as a value.
	var sd []string = new(3) []string { "", "", "a" }
	if slices.CountUniqueString(sd) == 2 { pass = pass + 1 }

	// Matches UniqueInts length.
	var e []int = new(6) []int { 1, 2, 1, 3, 2, 1 }
	var f []int = new(6) []int { 1, 2, 1, 3, 2, 1 }
	var u []int = slices.UniqueInts(e)
	if slices.CountUniqueInt(f) == len(u) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
