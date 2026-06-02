package main
import "log"
import "slices"

// Positive test: slices.EqualInts / EqualStrings / MinString / MaxString.

fun main() int {
	var pass int = 0

	// EqualInts: same.
	var a1 []int = new(3) []int{1, 2, 3}
	var b1 []int = new(3) []int{1, 2, 3}
	if slices.EqualInts(a1, b1) { pass = pass + 1 }

	// EqualInts: different at one index.
	var a2 []int = new(3) []int{1, 2, 3}
	var b2 []int = new(3) []int{1, 2, 9}
	if !slices.EqualInts(a2, b2) { pass = pass + 1 }

	// EqualInts: different lengths.
	var a3 []int = new(2) []int{1, 2}
	var b3 []int = new(3) []int{1, 2, 3}
	if !slices.EqualInts(a3, b3) { pass = pass + 1 }

	// EqualInts: both empty.
	var a4 []int = new(0) []int{}
	var b4 []int = new(0) []int{}
	if slices.EqualInts(a4, b4) { pass = pass + 1 }

	// EqualStrings.
	var s1 []string = new(3) []string{"a", "b", "c"}
	var t1 []string = new(3) []string{"a", "b", "c"}
	if slices.EqualStrings(s1, t1) { pass = pass + 1 }

	var s2 []string = new(2) []string{"a", "b"}
	var t2 []string = new(2) []string{"a", "x"}
	if !slices.EqualStrings(s2, t2) { pass = pass + 1 }

	// MinString.
	var s3 []string = new(4) []string{"banana", "apple", "cherry", "date"}
	if slices.MinString(s3) == "apple" { pass = pass + 1 }

	// MaxString.
	var s4 []string = new(4) []string{"banana", "apple", "cherry", "date"}
	if slices.MaxString(s4) == "date" { pass = pass + 1 }

	// MinString / MaxString on empty input.
	var s5 []string = new(0) []string{}
	if slices.MinString(s5) == "" { pass = pass + 1 }
	var s6 []string = new(0) []string{}
	if slices.MaxString(s6) == "" { pass = pass + 1 }

	// Single-element slice.
	var s7 []string = new(1) []string{"solo"}
	if slices.MinString(s7) == "solo" { pass = pass + 1 }
	var s8 []string = new(1) []string{"solo"}
	if slices.MaxString(s8) == "solo" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
