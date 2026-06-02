package main
import "log"
import "slices"

// Positive test: slices.NegateInt + slices.AbsValuesInt.

fun main() int {
	var pass int = 0

	// NegateInt — positives flip negative.
	var n1 []int = slices.NegateInt(new(4) []int { 1, 2, 3, 4 })
	if len(n1) == 4 { pass = pass + 1 }
	if n1[0] == -1 { pass = pass + 1 }
	if n1[1] == -2 { pass = pass + 1 }
	if n1[2] == -3 { pass = pass + 1 }
	if n1[3] == -4 { pass = pass + 1 }

	// NegateInt — negatives flip positive.
	var n2 []int = slices.NegateInt(new(3) []int { -5, -10, -15 })
	if n2[0] == 5 { pass = pass + 1 }
	if n2[1] == 10 { pass = pass + 1 }
	if n2[2] == 15 { pass = pass + 1 }

	// NegateInt — zeros stay zero.
	var n3 []int = slices.NegateInt(new(3) []int { 0, 0, 0 })
	if n3[0] == 0 { pass = pass + 1 }

	// NegateInt — empty.
	var n4 []int = slices.NegateInt(new(0) []int {})
	if len(n4) == 0 { pass = pass + 1 }

	// NegateInt — original unchanged.
	var orig []int = new(3) []int { 1, 2, 3 }
	var negated []int = slices.NegateInt(orig)
	if orig[0] == 1 { pass = pass + 1 }
	if negated[0] == -1 { pass = pass + 1 }

	// AbsValuesInt — basic.
	var a1 []int = slices.AbsValuesInt(new(5) []int { -3, -1, 0, 2, 5 })
	if a1[0] == 3 { pass = pass + 1 }
	if a1[1] == 1 { pass = pass + 1 }
	if a1[2] == 0 { pass = pass + 1 }
	if a1[3] == 2 { pass = pass + 1 }
	if a1[4] == 5 { pass = pass + 1 }

	// AbsValuesInt — all positive (identity).
	var a2 []int = slices.AbsValuesInt(new(3) []int { 7, 8, 9 })
	if a2[0] == 7 { pass = pass + 1 }
	if a2[1] == 8 { pass = pass + 1 }

	// AbsValuesInt — all negative (full flip).
	var a3 []int = slices.AbsValuesInt(new(3) []int { -1, -2, -3 })
	if a3[0] == 1 { pass = pass + 1 }
	if a3[2] == 3 { pass = pass + 1 }

	// AbsValuesInt — empty.
	var a4 []int = slices.AbsValuesInt(new(0) []int {})
	if len(a4) == 0 { pass = pass + 1 }

	// Identity: Negate(Negate(s)) == s.
	var sample []int = new(3) []int { 5, -10, 15 }
	var twiceNeg []int = slices.NegateInt(slices.NegateInt(sample))
	if twiceNeg[0] == 5 { pass = pass + 1 }
	if twiceNeg[1] == -10 { pass = pass + 1 }
	if twiceNeg[2] == 15 { pass = pass + 1 }

	// Identity: AbsValuesInt(AbsValuesInt(s)) == AbsValuesInt(s).
	var twiceAbs []int = slices.AbsValuesInt(slices.AbsValuesInt(sample))
	if twiceAbs[0] == 5 { pass = pass + 1 }
	if twiceAbs[1] == 10 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
