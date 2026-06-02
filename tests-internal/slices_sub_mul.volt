package main
import "log"
import "slices"

// Positive test: slices.SubInt + slices.MulInt.

fun main() int {
	var pass int = 0

	// SubInt — basic.
	var r1 []int = slices.SubInt(new(4) []int { 10, 20, 30, 40 }, new(4) []int { 1, 2, 3, 4 })
	if len(r1) == 4 { pass = pass + 1 }
	if r1[0] == 9 { pass = pass + 1 }
	if r1[1] == 18 { pass = pass + 1 }
	if r1[2] == 27 { pass = pass + 1 }
	if r1[3] == 36 { pass = pass + 1 }

	// SubInt — length mismatch.
	var r2 []int = slices.SubInt(new(2) []int { 5, 10 }, new(4) []int { 1, 2, 99, 99 })
	if len(r2) == 2 { pass = pass + 1 }
	if r2[0] == 4 { pass = pass + 1 }
	if r2[1] == 8 { pass = pass + 1 }

	// SubInt — negatives (result negative).
	var r3 []int = slices.SubInt(new(3) []int { 1, 2, 3 }, new(3) []int { 4, 5, 6 })
	if r3[0] == -3 { pass = pass + 1 }
	if r3[2] == -3 { pass = pass + 1 }

	// SubInt — same slice → zero vector.
	var same []int = new(3) []int { 7, 8, 9 }
	var zero []int = slices.SubInt(same, same)
	if zero[0] == 0 { pass = pass + 1 }
	if zero[1] == 0 { pass = pass + 1 }
	if zero[2] == 0 { pass = pass + 1 }

	// SubInt — empty.
	var r4 []int = slices.SubInt(new(0) []int {}, new(3) []int { 1, 2, 3 })
	if len(r4) == 0 { pass = pass + 1 }

	// MulInt — basic.
	var m1 []int = slices.MulInt(new(4) []int { 1, 2, 3, 4 }, new(4) []int { 10, 20, 30, 40 })
	if m1[0] == 10 { pass = pass + 1 }
	if m1[1] == 40 { pass = pass + 1 }
	if m1[2] == 90 { pass = pass + 1 }
	if m1[3] == 160 { pass = pass + 1 }

	// MulInt — mask application (1/0 selector).
	var m2 []int = slices.MulInt(new(5) []int { 10, 20, 30, 40, 50 }, new(5) []int { 1, 0, 1, 0, 1 })
	if m2[0] == 10 { pass = pass + 1 }
	if m2[1] == 0 { pass = pass + 1 }
	if m2[2] == 30 { pass = pass + 1 }
	if m2[3] == 0 { pass = pass + 1 }
	if m2[4] == 50 { pass = pass + 1 }

	// MulInt — empty operand.
	var m3 []int = slices.MulInt(new(0) []int {}, new(3) []int { 1, 2, 3 })
	if len(m3) == 0 { pass = pass + 1 }

	// MulInt — Sum(Mul(a, b)) == DotInt(a, b).
	var dotA []int = new(3) []int { 2, 3, 4 }
	var dotB []int = new(3) []int { 5, 6, 7 }
	if slices.SumInts(slices.MulInt(dotA, dotB)) == slices.DotInt(dotA, dotB) { pass = pass + 1 }

	// Add(a, Sub(b, a)) == b (when same length).
	var x []int = new(3) []int { 1, 2, 3 }
	var y []int = new(3) []int { 10, 20, 30 }
	var diff []int = slices.SubInt(y, x)
	var back []int = slices.AddInt(x, diff)
	if back[0] == 10 { pass = pass + 1 }
	if back[2] == 30 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
