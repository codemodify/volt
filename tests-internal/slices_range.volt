package main
import "log"
import "slices"

// Positive test: slices.RangeInts / RangeIntsStep — Python-style
// range() generators returning []int.

fun main() int {
	var pass int = 0

	// RangeInts(0, 5) → [0, 1, 2, 3, 4]
	var r1 []int = slices.RangeInts(0, 5)
	if len(r1) == 5 { pass = pass + 1 }
	if r1[0] == 0 { pass = pass + 1 }
	if r1[4] == 4 { pass = pass + 1 }

	// RangeInts(3, 7) → [3, 4, 5, 6]
	var r2 []int = slices.RangeInts(3, 7)
	if len(r2) == 4 { pass = pass + 1 }
	if r2[0] == 3 { pass = pass + 1 }
	if r2[3] == 6 { pass = pass + 1 }

	// RangeInts(5, 5) → empty.
	var r3 []int = slices.RangeInts(5, 5)
	if len(r3) == 0 { pass = pass + 1 }

	// RangeInts(10, 0) → empty (start >= end).
	var r4 []int = slices.RangeInts(10, 0)
	if len(r4) == 0 { pass = pass + 1 }

	// RangeIntsStep(0, 10, 2) → [0, 2, 4, 6, 8]
	var r5 []int = slices.RangeIntsStep(0, 10, 2)
	if len(r5) == 5 { pass = pass + 1 }
	if r5[0] == 0 { pass = pass + 1 }
	if r5[2] == 4 { pass = pass + 1 }
	if r5[4] == 8 { pass = pass + 1 }

	// RangeIntsStep(5, 0, -1) → [5, 4, 3, 2, 1]
	var r6 []int = slices.RangeIntsStep(5, 0, -1)
	if len(r6) == 5 { pass = pass + 1 }
	if r6[0] == 5 { pass = pass + 1 }
	if r6[4] == 1 { pass = pass + 1 }

	// RangeIntsStep(0, 0, 1) → empty (start == end).
	var r7 []int = slices.RangeIntsStep(0, 0, 1)
	if len(r7) == 0 { pass = pass + 1 }

	// RangeIntsStep(0, 10, 0) → empty (zero step).
	var r8 []int = slices.RangeIntsStep(0, 10, 0)
	if len(r8) == 0 { pass = pass + 1 }

	// RangeIntsStep(1, 10, 3) → [1, 4, 7]
	var r9 []int = slices.RangeIntsStep(1, 10, 3)
	if len(r9) == 3 { pass = pass + 1 }
	if r9[2] == 7 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
