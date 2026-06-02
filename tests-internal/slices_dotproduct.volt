package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	var f []int = new(0) []int {}
	if slices.DotProductInt(e, f) == 0 { pass = pass + 1 }

	// One side empty.
	var a1 []int = new(3) []int { 1, 2, 3 }
	var b1 []int = new(0) []int {}
	if slices.DotProductInt(a1, b1) == 0 { pass = pass + 1 }

	// Same length: classic dot.
	var a2 []int = new(3) []int { 1, 2, 3 }
	var b2 []int = new(3) []int { 4, 5, 6 }
	// 1*4 + 2*5 + 3*6 = 4 + 10 + 18 = 32
	if slices.DotProductInt(a2, b2) == 32 { pass = pass + 1 }

	// Mismatched length: extra tail of longer is ignored.
	var a3 []int = new(2) []int { 1, 2 }
	var b3 []int = new(3) []int { 10, 20, 999 }
	// only 1*10 + 2*20 = 50
	if slices.DotProductInt(a3, b3) == 50 { pass = pass + 1 }
	var a3b []int = new(3) []int { 10, 20, 999 }
	var b3b []int = new(2) []int { 1, 2 }
	if slices.DotProductInt(a3b, b3b) == 50 { pass = pass + 1 }

	// Negative values.
	var a4 []int = new(3) []int { 1, -2, 3 }
	var b4 []int = new(3) []int { 4, 5, -6 }
	// 4 + -10 + -18 = -24
	if slices.DotProductInt(a4, b4) == -24 { pass = pass + 1 }

	// All zero.
	var a5 []int = new(5) []int { 0, 0, 0, 0, 0 }
	var b5 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.DotProductInt(a5, b5) == 0 { pass = pass + 1 }

	// Orthogonal vectors → 0.
	var a6 []int = new(3) []int { 1, 0, 0 }
	var b6 []int = new(3) []int { 0, 1, 0 }
	if slices.DotProductInt(a6, b6) == 0 { pass = pass + 1 }

	// Cauchy-Schwarz sanity: |a·a| = |a|² (sum of squares).
	var a7 []int = new(4) []int { 1, 2, 3, 4 }
	var a7b []int = new(4) []int { 1, 2, 3, 4 }
	if slices.DotProductInt(a7, a7b) == 30 { pass = pass + 1 }   // 1+4+9+16=30

	// Single-element.
	var a8 []int = new(1) []int { 7 }
	var b8 []int = new(1) []int { 6 }
	if slices.DotProductInt(a8, b8) == 42 { pass = pass + 1 }

	// Commutative: a·b == b·a.
	var a9 []int = new(3) []int { 2, 3, 5 }
	var b9 []int = new(3) []int { 7, 11, 13 }
	var d1 int = slices.DotProductInt(a9, b9)
	var a9b []int = new(3) []int { 7, 11, 13 }
	var b9b []int = new(3) []int { 2, 3, 5 }
	var d2 int = slices.DotProductInt(a9b, b9b)
	if d1 == d2 { pass = pass + 1 }

	// Weighted sum use case: dot(values, weights).
	var values []int = new(4) []int { 90, 75, 80, 95 }
	var weights []int = new(4) []int { 3, 2, 2, 3 }
	// 270 + 150 + 160 + 285 = 865
	if slices.DotProductInt(values, weights) == 865 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
