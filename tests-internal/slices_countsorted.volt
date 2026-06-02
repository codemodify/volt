package main
import "log"
import "slices"

// Positive test: slices.CountSortedInt + slices.CountSortedString.

fun main() int {
	var pass int = 0

	// CountSortedInt — basic.
	var s1 []int = new(7) []int { 1, 2, 2, 2, 3, 4, 5 }
	if slices.CountSortedInt(s1, 2) == 3 { pass = pass + 1 }
	if slices.CountSortedInt(s1, 1) == 1 { pass = pass + 1 }
	if slices.CountSortedInt(s1, 5) == 1 { pass = pass + 1 }

	// CountSortedInt — absent.
	if slices.CountSortedInt(s1, 99) == 0 { pass = pass + 1 }
	if slices.CountSortedInt(s1, 0) == 0 { pass = pass + 1 }

	// CountSortedInt — empty.
	if slices.CountSortedInt(new(0) []int {}, 5) == 0 { pass = pass + 1 }

	// CountSortedInt — all-same.
	var s2 []int = new(4) []int { 7, 7, 7, 7 }
	if slices.CountSortedInt(s2, 7) == 4 { pass = pass + 1 }
	if slices.CountSortedInt(s2, 8) == 0 { pass = pass + 1 }

	// CountSortedInt — singleton.
	if slices.CountSortedInt(new(1) []int { 42 }, 42) == 1 { pass = pass + 1 }

	// CountSortedString — basic.
	var t1 []string = new(6) []string { "a", "b", "b", "b", "c", "d" }
	if slices.CountSortedString(t1, "b") == 3 { pass = pass + 1 }
	if slices.CountSortedString(t1, "a") == 1 { pass = pass + 1 }
	if slices.CountSortedString(t1, "c") == 1 { pass = pass + 1 }
	if slices.CountSortedString(t1, "zz") == 0 { pass = pass + 1 }

	// CountSortedString — empty.
	if slices.CountSortedString(new(0) []string {}, "x") == 0 { pass = pass + 1 }

	// CountSortedString — all-same.
	var t2 []string = new(3) []string { "foo", "foo", "foo" }
	if slices.CountSortedString(t2, "foo") == 3 { pass = pass + 1 }

	// Frequency cross-check (CountSorted == UpperBound - LowerBound).
	if slices.CountSortedInt(s1, 2) == slices.UpperBoundInt(s1, 2) - slices.LowerBoundInt(s1, 2) { pass = pass + 1 }
	if slices.CountSortedString(t1, "b") == slices.UpperBoundString(t1, "b") - slices.LowerBoundString(t1, "b") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
