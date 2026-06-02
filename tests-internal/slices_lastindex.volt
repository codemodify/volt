package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// LastIndexInt — basic right-to-left scan.
	var ints []int = new(6) []int { 1, 2, 3, 2, 1, 2 }
	if slices.LastIndexInt(ints, 2) == 5 { pass = pass + 1 }
	if slices.LastIndexInt(ints, 1) == 4 { pass = pass + 1 }
	if slices.LastIndexInt(ints, 3) == 2 { pass = pass + 1 }
	if slices.LastIndexInt(ints, 99) == -1 { pass = pass + 1 }

	// LastIndexInt — single-element.
	var solo []int = new(1) []int { 42 }
	if slices.LastIndexInt(solo, 42) == 0 { pass = pass + 1 }
	if slices.LastIndexInt(solo, 0) == -1 { pass = pass + 1 }

	// LastIndexInt — empty input.
	var empty []int = new(0) []int {}
	if slices.LastIndexInt(empty, 5) == -1 { pass = pass + 1 }

	// LastIndexInt — negative values.
	var withNeg []int = new(4) []int { -1, 2, -1, 0 }
	if slices.LastIndexInt(withNeg, -1) == 2 { pass = pass + 1 }
	if slices.LastIndexInt(withNeg, 0) == 3 { pass = pass + 1 }

	// LastIndexString — parallel suite.
	var strs []string = new(5) []string { "a", "b", "a", "c", "a" }
	if slices.LastIndexString(strs, "a") == 4 { pass = pass + 1 }
	if slices.LastIndexString(strs, "b") == 1 { pass = pass + 1 }
	if slices.LastIndexString(strs, "c") == 3 { pass = pass + 1 }
	if slices.LastIndexString(strs, "z") == -1 { pass = pass + 1 }

	// LastIndexString — empty.
	var es []string = new(0) []string {}
	if slices.LastIndexString(es, "x") == -1 { pass = pass + 1 }

	// LastIndexString — preserves identity vs IndexString on
	// single-occurrence slice.
	var single []string = new(3) []string { "x", "y", "z" }
	if slices.IndexString(single, "y") == 1 { pass = pass + 1 }
	if slices.LastIndexString(single, "y") == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
