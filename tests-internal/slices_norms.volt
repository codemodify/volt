package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	if slices.SumAbsInt(e) == 0 { pass = pass + 1 }
	var e2 []int = new(0) []int {}
	if slices.SumSquaresInt(e2) == 0 { pass = pass + 1 }

	// All positive — SumAbs = Sum.
	var s1 []int = new(4) []int { 1, 2, 3, 4 }
	if slices.SumAbsInt(s1) == 10 { pass = pass + 1 }
	var s1b []int = new(4) []int { 1, 2, 3, 4 }
	if slices.SumSquaresInt(s1b) == 30 { pass = pass + 1 }   // 1+4+9+16

	// Mixed signs — SumAbs counts magnitude only.
	var s2 []int = new(4) []int { -1, -2, 3, 4 }
	if slices.SumAbsInt(s2) == 10 { pass = pass + 1 }
	var s2b []int = new(4) []int { -1, -2, 3, 4 }
	if slices.SumSquaresInt(s2b) == 30 { pass = pass + 1 }   // squared kills sign

	// All-zero.
	var s3 []int = new(5) []int { 0, 0, 0, 0, 0 }
	if slices.SumAbsInt(s3) == 0 { pass = pass + 1 }
	var s3b []int = new(5) []int { 0, 0, 0, 0, 0 }
	if slices.SumSquaresInt(s3b) == 0 { pass = pass + 1 }

	// All-negative.
	var s4 []int = new(3) []int { -5, -10, -15 }
	if slices.SumAbsInt(s4) == 30 { pass = pass + 1 }
	var s4b []int = new(3) []int { -5, -10, -15 }
	if slices.SumSquaresInt(s4b) == 350 { pass = pass + 1 }   // 25+100+225

	// Single element.
	var s5 []int = new(1) []int { -7 }
	if slices.SumAbsInt(s5) == 7 { pass = pass + 1 }
	var s5b []int = new(1) []int { -7 }
	if slices.SumSquaresInt(s5b) == 49 { pass = pass + 1 }

	// Pythagorean triple: 3² + 4² = 25 == 5².
	var s6 []int = new(2) []int { 3, 4 }
	if slices.SumSquaresInt(s6) == 25 { pass = pass + 1 }

	// SumSquares matches DotProduct(s, s).
	var s7 []int = new(4) []int { 2, -3, 5, -7 }
	var s7copy []int = new(4) []int { 2, -3, 5, -7 }
	var ss int = slices.SumSquaresInt(s7)
	var dp int = slices.DotProductInt(s7copy, s7copy)
	if ss == dp { pass = pass + 1 }

	// SumAbs >= |Sum| (triangle inequality on scalars).
	var s8 []int = new(4) []int { 5, -3, 7, -2 }
	var s8b []int = new(4) []int { 5, -3, 7, -2 }
	var abs int = slices.SumAbsInt(s8)
	var sm int = slices.SumInts(s8b)
	if sm < 0 { sm = -sm }
	if abs >= sm { pass = pass + 1 }

	// Movement-from-zero use case: walk steps.
	var steps []int = new(6) []int { 3, -2, 5, -4, 1, -1 }
	if slices.SumAbsInt(steps) == 16 { pass = pass + 1 }   // total distance traveled

	// Doesn't mutate s.
	var s9 []int = new(3) []int { 1, -2, 3 }
	var a int = slices.SumAbsInt(s9)
	var b int = slices.SumSquaresInt(s9)
	if a == 6 { pass = pass + 1 }
	if b == 14 { pass = pass + 1 }
	if s9[0] == 1 { pass = pass + 1 }
	if s9[1] == -2 { pass = pass + 1 }
	if s9[2] == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
