package main
import "log"
import "slices"

// Positive test: slices.AllSameInt + slices.AllSameString.

fun main() int {
	var pass int = 0

	// AllSameInt — all equal.
	var a []int = new(5) []int{7, 7, 7, 7, 7}
	if slices.AllSameInt(a) { pass = pass + 1 }

	// Mixed.
	var b []int = new(3) []int{1, 2, 1}
	if !slices.AllSameInt(b) { pass = pass + 1 }

	// One differs at end.
	var c []int = new(4) []int{5, 5, 5, 6}
	if !slices.AllSameInt(c) { pass = pass + 1 }

	// One differs at start.
	var d []int = new(4) []int{6, 5, 5, 5}
	if !slices.AllSameInt(d) { pass = pass + 1 }

	// Single → true.
	var e []int = new(1) []int{42}
	if slices.AllSameInt(e) { pass = pass + 1 }

	// Empty → vacuously true.
	var f []int = new(0) []int{}
	if slices.AllSameInt(f) { pass = pass + 1 }

	// Negatives all-same.
	var g []int = new(3) []int{-3, -3, -3}
	if slices.AllSameInt(g) { pass = pass + 1 }

	// Zero all-same.
	var z []int = new(4) []int{0, 0, 0, 0}
	if slices.AllSameInt(z) { pass = pass + 1 }

	// AllSameString — all equal.
	var s1 []string = new(3) []string{"x", "x", "x"}
	if slices.AllSameString(s1) { pass = pass + 1 }

	// Mixed.
	var s2 []string = new(3) []string{"a", "b", "a"}
	if !slices.AllSameString(s2) { pass = pass + 1 }

	// Empty → true.
	var s3 []string = new(0) []string{}
	if slices.AllSameString(s3) { pass = pass + 1 }

	// Single → true.
	var s4 []string = new(1) []string{"only"}
	if slices.AllSameString(s4) { pass = pass + 1 }

	// Empty-string elements (still all-same).
	var s5 []string = new(3) []string{"", "", ""}
	if slices.AllSameString(s5) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
