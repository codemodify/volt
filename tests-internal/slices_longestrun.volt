package main
import "log"
import "slices"

// Positive test: slices.LongestRunInt + LongestRunString.

fun main() int {
	var pass int = 0

	// Run in the middle.
	var a []int = new(7) []int{1, 2, 2, 2, 3, 4, 4}
	if slices.LongestRunInt(a) == 3 { pass = pass + 1 }

	// All distinct.
	var b []int = new(5) []int{1, 2, 3, 4, 5}
	if slices.LongestRunInt(b) == 1 { pass = pass + 1 }

	// All same.
	var c []int = new(6) []int{7, 7, 7, 7, 7, 7}
	if slices.LongestRunInt(c) == 6 { pass = pass + 1 }

	// Single element.
	var d []int = new(1) []int{42}
	if slices.LongestRunInt(d) == 1 { pass = pass + 1 }

	// Empty.
	var e []int = new(0) []int{}
	if slices.LongestRunInt(e) == 0 { pass = pass + 1 }

	// Run at start.
	var f []int = new(5) []int{9, 9, 9, 1, 2}
	if slices.LongestRunInt(f) == 3 { pass = pass + 1 }

	// Run at end.
	var g []int = new(5) []int{1, 2, 9, 9, 9}
	if slices.LongestRunInt(g) == 3 { pass = pass + 1 }

	// Multiple runs, longest wins.
	var h []int = new(9) []int{1, 1, 2, 2, 2, 2, 3, 3, 3}
	if slices.LongestRunInt(h) == 4 { pass = pass + 1 }

	// Alternating no run > 1.
	var alt []int = new(6) []int{1, 2, 1, 2, 1, 2}
	if slices.LongestRunInt(alt) == 1 { pass = pass + 1 }

	// LongestRunString — basic run.
	var s1 []string = new(6) []string{"a", "b", "b", "b", "c", "a"}
	if slices.LongestRunString(s1) == 3 { pass = pass + 1 }

	// LongestRunString empty / single.
	var s2 []string = new(0) []string{}
	if slices.LongestRunString(s2) == 0 { pass = pass + 1 }

	var s3 []string = new(1) []string{"only"}
	if slices.LongestRunString(s3) == 1 { pass = pass + 1 }

	// LongestRunString all same.
	var s4 []string = new(4) []string{"x", "x", "x", "x"}
	if slices.LongestRunString(s4) == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
