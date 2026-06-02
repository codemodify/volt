package main
import "log"
import "slices"

// Positive test: slices.SquareInt + slices.SignInt.

fun main() int {
	var pass int = 0

	// SquareInt — basic positives.
	var sq1 []int = slices.SquareInt(new(4) []int { 1, 2, 3, 4 })
	if len(sq1) == 4 { pass = pass + 1 }
	if sq1[0] == 1 { pass = pass + 1 }
	if sq1[1] == 4 { pass = pass + 1 }
	if sq1[2] == 9 { pass = pass + 1 }
	if sq1[3] == 16 { pass = pass + 1 }

	// SquareInt — negatives produce positive squares.
	var sq2 []int = slices.SquareInt(new(3) []int { -2, -3, -4 })
	if sq2[0] == 4 { pass = pass + 1 }
	if sq2[1] == 9 { pass = pass + 1 }
	if sq2[2] == 16 { pass = pass + 1 }

	// SquareInt — zeros.
	var sq3 []int = slices.SquareInt(new(2) []int { 0, 0 })
	if sq3[0] == 0 { pass = pass + 1 }

	// SquareInt — empty.
	var sq4 []int = slices.SquareInt(new(0) []int {})
	if len(sq4) == 0 { pass = pass + 1 }

	// Sum-of-squares identity (matches DotInt(s, s)).
	var v []int = new(4) []int { 1, 2, 3, 4 }
	if slices.SumInts(slices.SquareInt(v)) == slices.DotInt(v, v) { pass = pass + 1 }

	// SignInt — basic.
	var sg1 []int = slices.SignInt(new(5) []int { -5, -1, 0, 1, 7 })
	if sg1[0] == -1 { pass = pass + 1 }
	if sg1[1] == -1 { pass = pass + 1 }
	if sg1[2] == 0 { pass = pass + 1 }
	if sg1[3] == 1 { pass = pass + 1 }
	if sg1[4] == 1 { pass = pass + 1 }

	// SignInt — all positive → all 1s.
	var sg2 []int = slices.SignInt(new(3) []int { 100, 200, 1 })
	if sg2[0] == 1 { pass = pass + 1 }
	if sg2[2] == 1 { pass = pass + 1 }

	// SignInt — all negative → all -1s.
	var sg3 []int = slices.SignInt(new(3) []int { -100, -1, -200 })
	if sg3[0] == -1 { pass = pass + 1 }
	if sg3[2] == -1 { pass = pass + 1 }

	// SignInt — all zeros → all zeros.
	var sg4 []int = slices.SignInt(new(3) []int { 0, 0, 0 })
	if sg4[0] == 0 { pass = pass + 1 }
	if sg4[1] == 0 { pass = pass + 1 }

	// SignInt — empty.
	var sg5 []int = slices.SignInt(new(0) []int {})
	if len(sg5) == 0 { pass = pass + 1 }

	// SignInt * AbsValues == original (for non-zero elements).
	var src []int = new(4) []int { -3, 5, -7, 11 }
	var signs []int = slices.SignInt(src)
	var abs []int = slices.AbsValuesInt(src)
	var product []int = slices.MulInt(signs, abs)
	if product[0] == -3 { pass = pass + 1 }
	if product[1] == 5 { pass = pass + 1 }
	if product[2] == -7 { pass = pass + 1 }
	if product[3] == 11 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
