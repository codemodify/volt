package main
import "log"
import "slices"

// Positive test: slices.ModeInt / ModeString.

fun main() int {
	var pass int = 0

	// Clear winner.
	var a []int = new(6) []int{1, 2, 2, 3, 2, 4}
	if slices.ModeInt(a) == 2 { pass = pass + 1 }

	// Single element.
	var b []int = new(1) []int{99}
	if slices.ModeInt(b) == 99 { pass = pass + 1 }

	// All same.
	var c []int = new(4) []int{5, 5, 5, 5}
	if slices.ModeInt(c) == 5 { pass = pass + 1 }

	// All distinct — first wins ties.
	var d []int = new(5) []int{7, 1, 2, 3, 4}
	if slices.ModeInt(d) == 7 { pass = pass + 1 }

	// Tie — earliest wins.
	var e []int = new(4) []int{3, 1, 3, 1}
	if slices.ModeInt(e) == 3 { pass = pass + 1 }   // both appear twice; 3 first

	// Tie reversed.
	var f []int = new(4) []int{1, 3, 1, 3}
	if slices.ModeInt(f) == 1 { pass = pass + 1 }   // both twice; 1 first

	// Negatives.
	var g []int = new(5) []int{-1, -1, 0, 1, 1}
	if slices.ModeInt(g) == -1 { pass = pass + 1 }   // -1 and 1 both twice; -1 first

	// Empty.
	var h []int = new(0) []int{}
	if slices.ModeInt(h) == 0 { pass = pass + 1 }

	// ModeString — clear winner.
	var s1 []string = new(5) []string{"a", "b", "a", "c", "a"}
	if slices.ModeString(s1) == "a" { pass = pass + 1 }

	// ModeString — single.
	var s2 []string = new(1) []string{"hello"}
	if slices.ModeString(s2) == "hello" { pass = pass + 1 }

	// ModeString — tie, first wins.
	var s3 []string = new(4) []string{"foo", "bar", "foo", "bar"}
	if slices.ModeString(s3) == "foo" { pass = pass + 1 }

	// ModeString — empty.
	var s4 []string = new(0) []string{}
	if slices.ModeString(s4) == "" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
