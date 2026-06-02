package main
import "log"
import "slices"

// Positive test: slices.ScaleInt + slices.ShiftInt.

fun main() int {
	var pass int = 0

	// ScaleInt — basic.
	var r1 []int = slices.ScaleInt(new(4) []int { 1, 2, 3, 4 }, 10)
	if len(r1) == 4 { pass = pass + 1 }
	if r1[0] == 10 { pass = pass + 1 }
	if r1[1] == 20 { pass = pass + 1 }
	if r1[2] == 30 { pass = pass + 1 }
	if r1[3] == 40 { pass = pass + 1 }

	// ScaleInt — factor 0 zeros all elements.
	var r2 []int = slices.ScaleInt(new(3) []int { 5, 7, 9 }, 0)
	if r2[0] == 0 { pass = pass + 1 }
	if r2[1] == 0 { pass = pass + 1 }
	if r2[2] == 0 { pass = pass + 1 }

	// ScaleInt — factor 1 returns identity copy.
	var r3 []int = slices.ScaleInt(new(3) []int { 1, 2, 3 }, 1)
	if r3[0] == 1 { pass = pass + 1 }
	if r3[1] == 2 { pass = pass + 1 }
	if r3[2] == 3 { pass = pass + 1 }

	// ScaleInt — negative factor flips sign.
	var r4 []int = slices.ScaleInt(new(3) []int { 1, 2, 3 }, -2)
	if r4[0] == -2 { pass = pass + 1 }
	if r4[1] == -4 { pass = pass + 1 }
	if r4[2] == -6 { pass = pass + 1 }

	// ScaleInt — empty input.
	var r5 []int = slices.ScaleInt(new(0) []int {}, 5)
	if len(r5) == 0 { pass = pass + 1 }

	// ShiftInt — basic.
	var s1 []int = slices.ShiftInt(new(4) []int { 1, 2, 3, 4 }, 10)
	if s1[0] == 11 { pass = pass + 1 }
	if s1[1] == 12 { pass = pass + 1 }
	if s1[2] == 13 { pass = pass + 1 }
	if s1[3] == 14 { pass = pass + 1 }

	// ShiftInt — offset 0 returns identity copy.
	var s2 []int = slices.ShiftInt(new(3) []int { 1, 2, 3 }, 0)
	if s2[0] == 1 { pass = pass + 1 }
	if s2[2] == 3 { pass = pass + 1 }

	// ShiftInt — negative offset.
	var s3 []int = slices.ShiftInt(new(3) []int { 10, 20, 30 }, -5)
	if s3[0] == 5 { pass = pass + 1 }
	if s3[1] == 15 { pass = pass + 1 }
	if s3[2] == 25 { pass = pass + 1 }

	// ShiftInt — empty input.
	var s4 []int = slices.ShiftInt(new(0) []int {}, 5)
	if len(s4) == 0 { pass = pass + 1 }

	// Original unchanged after Scale.
	var orig []int = new(3) []int { 1, 2, 3 }
	var scaled []int = slices.ScaleInt(orig, 100)
	if orig[0] == 1 { pass = pass + 1 }
	if scaled[0] == 100 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
