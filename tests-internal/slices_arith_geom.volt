package main
import "log"
import "slices"

// Positive test: slices.IsArithmeticInt + slices.IsGeometricInt.

fun main() int {
	var pass int = 0

	// IsArithmeticInt — d=1.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	if slices.IsArithmeticInt(a) { pass = pass + 1 }

	// d=3.
	var b []int = new(4) []int{2, 5, 8, 11}
	if slices.IsArithmeticInt(b) { pass = pass + 1 }

	// d=-2.
	var c []int = new(4) []int{10, 8, 6, 4}
	if slices.IsArithmeticInt(c) { pass = pass + 1 }

	// d=0 — all same.
	var d []int = new(3) []int{7, 7, 7}
	if slices.IsArithmeticInt(d) { pass = pass + 1 }

	// Not arithmetic.
	var e []int = new(4) []int{1, 2, 4, 8}
	if !slices.IsArithmeticInt(e) { pass = pass + 1 }

	// Off by one in the middle.
	var f []int = new(5) []int{1, 2, 3, 5, 6}
	if !slices.IsArithmeticInt(f) { pass = pass + 1 }

	// Empty + single.
	var em []int = new(0) []int{}
	if slices.IsArithmeticInt(em) { pass = pass + 1 }
	var sg []int = new(1) []int{42}
	if slices.IsArithmeticInt(sg) { pass = pass + 1 }

	// Two elements always arithmetic.
	var two []int = new(2) []int{3, 99}
	if slices.IsArithmeticInt(two) { pass = pass + 1 }

	// IsGeometricInt — r=2.
	var g1 []int = new(5) []int{1, 2, 4, 8, 16}
	if slices.IsGeometricInt(g1) { pass = pass + 1 }

	// r=3.
	var g2 []int = new(4) []int{1, 3, 9, 27}
	if slices.IsGeometricInt(g2) { pass = pass + 1 }

	// r=-2.
	var g3 []int = new(4) []int{1, -2, 4, -8}
	if slices.IsGeometricInt(g3) { pass = pass + 1 }

	// Constant ratio 1.
	var g4 []int = new(3) []int{5, 5, 5}
	if slices.IsGeometricInt(g4) { pass = pass + 1 }

	// Rejects fractional ratio.
	var g5 []int = new(3) []int{1, 2, 5}
	if !slices.IsGeometricInt(g5) { pass = pass + 1 }

	// Rejects non-divisible step.
	var g6 []int = new(4) []int{2, 4, 8, 17}
	if !slices.IsGeometricInt(g6) { pass = pass + 1 }

	// Zero element disqualifies.
	var g7 []int = new(3) []int{1, 0, 0}
	if !slices.IsGeometricInt(g7) { pass = pass + 1 }
	var g8 []int = new(3) []int{0, 1, 2}
	if !slices.IsGeometricInt(g8) { pass = pass + 1 }

	// Empty + single.
	if slices.IsGeometricInt(em) { pass = pass + 1 }
	if slices.IsGeometricInt(sg) { pass = pass + 1 }

	// Both predicates true: arithmetic with d=0 (all same nonzero) is also geometric with r=1.
	var both []int = new(3) []int{4, 4, 4}
	if slices.IsArithmeticInt(both) { pass = pass + 1 }
	if slices.IsGeometricInt(both) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
