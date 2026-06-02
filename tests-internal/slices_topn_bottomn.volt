package main
import "log"
import "slices"

// Positive test: slices.TopNInt + slices.BottomNInt.

fun main() int {
	var pass int = 0

	var src []int = new(7) []int { 3, 1, 4, 1, 5, 9, 2 }

	// TopNInt — top 3.
	var t3 []int = slices.TopNInt(src, 3)
	if len(t3) == 3 { pass = pass + 1 }
	if t3[0] == 9 { pass = pass + 1 }
	if t3[1] == 5 { pass = pass + 1 }
	if t3[2] == 4 { pass = pass + 1 }

	// TopNInt — top 1.
	var t1 []int = slices.TopNInt(src, 1)
	if len(t1) == 1 { pass = pass + 1 }
	if t1[0] == 9 { pass = pass + 1 }

	// TopNInt — n > len returns all sorted desc.
	var tAll []int = slices.TopNInt(src, 100)
	if len(tAll) == 7 { pass = pass + 1 }
	if tAll[0] == 9 { pass = pass + 1 }
	if tAll[6] == 1 { pass = pass + 1 }

	// TopNInt — empty.
	var tEmpty []int = slices.TopNInt(new(0) []int {}, 5)
	if len(tEmpty) == 0 { pass = pass + 1 }

	// TopNInt — n <= 0.
	var t0 []int = slices.TopNInt(src, 0)
	if len(t0) == 0 { pass = pass + 1 }
	var tNeg []int = slices.TopNInt(src, -3)
	if len(tNeg) == 0 { pass = pass + 1 }

	// BottomNInt — bottom 3.
	var b3 []int = slices.BottomNInt(src, 3)
	if len(b3) == 3 { pass = pass + 1 }
	if b3[0] == 1 { pass = pass + 1 }
	if b3[1] == 1 { pass = pass + 1 }
	if b3[2] == 2 { pass = pass + 1 }

	// BottomNInt — bottom 1.
	var bb1 []int = slices.BottomNInt(src, 1)
	if bb1[0] == 1 { pass = pass + 1 }

	// BottomNInt — empty.
	var bEmpty []int = slices.BottomNInt(new(0) []int {}, 5)
	if len(bEmpty) == 0 { pass = pass + 1 }

	// BottomNInt — n=0.
	var b0 []int = slices.BottomNInt(src, 0)
	if len(b0) == 0 { pass = pass + 1 }

	// TopN[0] = Max, BottomN[0] = Min.
	if t1[0] == slices.MaxInts(src) { pass = pass + 1 }
	if bb1[0] == slices.MinInts(src) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
