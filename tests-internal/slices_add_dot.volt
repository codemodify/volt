package main
import "log"
import "slices"

// Positive test: slices.AddInt + slices.DotInt.

fun main() int {
	var pass int = 0

	// AddInt — basic.
	var r1 []int = slices.AddInt(new(4) []int { 1, 2, 3, 4 }, new(4) []int { 10, 20, 30, 40 })
	if len(r1) == 4 { pass = pass + 1 }
	if r1[0] == 11 { pass = pass + 1 }
	if r1[1] == 22 { pass = pass + 1 }
	if r1[2] == 33 { pass = pass + 1 }
	if r1[3] == 44 { pass = pass + 1 }

	// AddInt — length mismatch: shorter wins.
	var r2 []int = slices.AddInt(new(2) []int { 1, 2 }, new(4) []int { 10, 20, 30, 40 })
	if len(r2) == 2 { pass = pass + 1 }
	if r2[0] == 11 { pass = pass + 1 }
	if r2[1] == 22 { pass = pass + 1 }

	// AddInt — negatives.
	var r3 []int = slices.AddInt(new(3) []int { 5, 5, 5 }, new(3) []int { -1, -2, -3 })
	if r3[0] == 4 { pass = pass + 1 }
	if r3[1] == 3 { pass = pass + 1 }
	if r3[2] == 2 { pass = pass + 1 }

	// AddInt — empty operand.
	var r4 []int = slices.AddInt(new(0) []int {}, new(3) []int { 1, 2, 3 })
	if len(r4) == 0 { pass = pass + 1 }

	// AddInt — both empty.
	var r5 []int = slices.AddInt(new(0) []int {}, new(0) []int {})
	if len(r5) == 0 { pass = pass + 1 }

	// DotInt — basic (1*4 + 2*5 + 3*6 = 32).
	if slices.DotInt(new(3) []int { 1, 2, 3 }, new(3) []int { 4, 5, 6 }) == 32 { pass = pass + 1 }

	// DotInt — orthogonal-ish (zeros out).
	if slices.DotInt(new(2) []int { 1, 0 }, new(2) []int { 0, 1 }) == 0 { pass = pass + 1 }

	// DotInt — identity (DotInt(a, 1s) == SumInts(a)).
	var v []int = new(4) []int { 7, 8, 9, 10 }
	var ones []int = new(4) []int { 1, 1, 1, 1 }
	if slices.DotInt(v, ones) == slices.SumInts(v) { pass = pass + 1 }

	// DotInt — empty operand → 0.
	if slices.DotInt(new(0) []int {}, new(3) []int { 1, 2, 3 }) == 0 { pass = pass + 1 }

	// DotInt — length mismatch uses shorter.
	if slices.DotInt(new(2) []int { 2, 3 }, new(4) []int { 1, 1, 99, 99 }) == 5 { pass = pass + 1 }

	// DotInt — negatives.
	if slices.DotInt(new(3) []int { 1, -1, 2 }, new(3) []int { 3, 4, -5 }) == -11 { pass = pass + 1 }

	// AddInt commutativity (a + b == b + a).
	var bb []int = new(3) []int { 100, 200, 300 }
	var cc []int = new(3) []int { 1, 2, 3 }
	var ab []int = slices.AddInt(bb, cc)
	var ba []int = slices.AddInt(cc, bb)
	if ab[0] == ba[0] { pass = pass + 1 }
	if ab[2] == ba[2] { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
