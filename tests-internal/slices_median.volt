package main
import "log"
import "slices"

// Positive test: slices.MedianInt.

fun main() int {
	var pass int = 0

	// Odd-length, sorted.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	if slices.MedianInt(a) == 3 { pass = pass + 1 }

	// Odd-length, unsorted (must sort copy internally).
	var b []int = new(5) []int{5, 1, 3, 2, 4}
	if slices.MedianInt(b) == 3 { pass = pass + 1 }

	// Even-length, average of two middles.
	var c []int = new(4) []int{1, 2, 3, 4}
	if slices.MedianInt(c) == 2 { pass = pass + 1 }   // (2+3)/2 = 2 (trunc)

	// Even-length, average rounded toward zero.
	var d []int = new(4) []int{1, 2, 4, 5}
	if slices.MedianInt(d) == 3 { pass = pass + 1 }   // (2+4)/2 = 3

	// Single element.
	var e []int = new(1) []int{42}
	if slices.MedianInt(e) == 42 { pass = pass + 1 }

	// Two elements — average.
	var f []int = new(2) []int{10, 20}
	if slices.MedianInt(f) == 15 { pass = pass + 1 }

	// Empty.
	var g []int = new(0) []int{}
	if slices.MedianInt(g) == 0 { pass = pass + 1 }

	// All equal.
	var h []int = new(5) []int{7, 7, 7, 7, 7}
	if slices.MedianInt(h) == 7 { pass = pass + 1 }

	// Negatives.
	var ne []int = new(5) []int{-3, -1, 0, 1, 3}
	if slices.MedianInt(ne) == 0 { pass = pass + 1 }

	// Negatives even.
	var ne2 []int = new(4) []int{-4, -2, 0, 2}
	if slices.MedianInt(ne2) == -1 { pass = pass + 1 }   // (-2+0)/2 = -1

	// Verify input not mutated.
	var orig []int = new(5) []int{5, 1, 3, 2, 4}
	var _ int = slices.MedianInt(orig)
	if orig[0] == 5 { pass = pass + 1 }   // first element of original is still 5
	if orig[1] == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
