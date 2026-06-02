package main
import "log"
import "slices"

// Positive test: slices.IsStrictlyIncreasingInt + IsStrictlyDecreasingInt.

fun main() int {
	var pass int = 0

	// IsStrictlyIncreasingInt — passes.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	if slices.IsStrictlyIncreasingInt(a) { pass = pass + 1 }

	var b []int = new(4) []int{-3, 0, 7, 100}
	if slices.IsStrictlyIncreasingInt(b) { pass = pass + 1 }

	// Two elements, ascending.
	var c []int = new(2) []int{5, 10}
	if slices.IsStrictlyIncreasingInt(c) { pass = pass + 1 }

	// Empty / single.
	var em []int = new(0) []int{}
	if slices.IsStrictlyIncreasingInt(em) { pass = pass + 1 }
	var sg []int = new(1) []int{42}
	if slices.IsStrictlyIncreasingInt(sg) { pass = pass + 1 }

	// IsStrictlyIncreasingInt — fails on equals.
	var d []int = new(3) []int{1, 1, 2}
	if !slices.IsStrictlyIncreasingInt(d) { pass = pass + 1 }

	// Fails on descent.
	var e []int = new(3) []int{3, 2, 1}
	if !slices.IsStrictlyIncreasingInt(e) { pass = pass + 1 }

	// Fails on single descent in mostly-increasing.
	var f []int = new(5) []int{1, 2, 5, 4, 6}
	if !slices.IsStrictlyIncreasingInt(f) { pass = pass + 1 }

	// IsStrictlyDecreasingInt — passes.
	var g []int = new(5) []int{5, 4, 3, 2, 1}
	if slices.IsStrictlyDecreasingInt(g) { pass = pass + 1 }

	var h []int = new(4) []int{100, 7, 0, -3}
	if slices.IsStrictlyDecreasingInt(h) { pass = pass + 1 }

	if slices.IsStrictlyDecreasingInt(em) { pass = pass + 1 }
	if slices.IsStrictlyDecreasingInt(sg) { pass = pass + 1 }

	// IsStrictlyDecreasingInt — fails on equals.
	var i []int = new(3) []int{3, 3, 1}
	if !slices.IsStrictlyDecreasingInt(i) { pass = pass + 1 }

	// Fails on ascent.
	if !slices.IsStrictlyDecreasingInt(a) { pass = pass + 1 }

	// Fails on single ascent in mostly-decreasing.
	var k []int = new(5) []int{5, 4, 5, 2, 1}
	if !slices.IsStrictlyDecreasingInt(k) { pass = pass + 1 }

	// All-same — neither strictly-inc nor strictly-dec.
	var s []int = new(3) []int{7, 7, 7}
	if !slices.IsStrictlyIncreasingInt(s) { pass = pass + 1 }
	if !slices.IsStrictlyDecreasingInt(s) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
