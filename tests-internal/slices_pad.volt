package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty input → all-pad.
	var e []int = new(0) []int {}
	var r1 []int = slices.PadLeftInt(e, 3, 9)
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == 9 { pass = pass + 1 }
	if r1[1] == 9 { pass = pass + 1 }
	if r1[2] == 9 { pass = pass + 1 }

	var e2 []int = new(0) []int {}
	var r2 []int = slices.PadRightInt(e2, 3, 9)
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 9 { pass = pass + 1 }
	if r2[2] == 9 { pass = pass + 1 }

	// n <= len → unchanged copy.
	var s1 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var r3 []int = slices.PadLeftInt(s1, 3, 0)
	if len(r3) == 5 { pass = pass + 1 }
	if r3[0] == 1 { pass = pass + 1 }
	if r3[4] == 5 { pass = pass + 1 }

	var s1b []int = new(5) []int { 1, 2, 3, 4, 5 }
	var r4 []int = slices.PadLeftInt(s1b, 5, 0)
	if len(r4) == 5 { pass = pass + 1 }

	// Pad-left: extend by 3 on left.
	var s2 []int = new(2) []int { 7, 8 }
	var r5 []int = slices.PadLeftInt(s2, 5, 0)
	if len(r5) == 5 { pass = pass + 1 }
	if r5[0] == 0 { pass = pass + 1 }
	if r5[1] == 0 { pass = pass + 1 }
	if r5[2] == 0 { pass = pass + 1 }
	if r5[3] == 7 { pass = pass + 1 }
	if r5[4] == 8 { pass = pass + 1 }

	// Pad-right: extend by 3 on right.
	var s3 []int = new(2) []int { 7, 8 }
	var r6 []int = slices.PadRightInt(s3, 5, 0)
	if len(r6) == 5 { pass = pass + 1 }
	if r6[0] == 7 { pass = pass + 1 }
	if r6[1] == 8 { pass = pass + 1 }
	if r6[2] == 0 { pass = pass + 1 }
	if r6[3] == 0 { pass = pass + 1 }
	if r6[4] == 0 { pass = pass + 1 }

	// Pad with non-zero value.
	var s4 []int = new(2) []int { 1, 2 }
	var r7 []int = slices.PadLeftInt(s4, 4, -1)
	if r7[0] == -1 { pass = pass + 1 }
	if r7[1] == -1 { pass = pass + 1 }
	if r7[2] == 1 { pass = pass + 1 }
	if r7[3] == 2 { pass = pass + 1 }

	// Doesn't mutate s.
	var s5 []int = new(3) []int { 1, 2, 3 }
	var _r []int = slices.PadLeftInt(s5, 5, 99)
	if s5[0] == 1 { pass = pass + 1 }
	if s5[1] == 2 { pass = pass + 1 }
	if s5[2] == 3 { pass = pass + 1 }

	// Pad+truncate use case: align to 8-byte boundary by padding.
	var raw []int = new(5) []int { 1, 2, 3, 4, 5 }
	var aligned []int = slices.PadRightInt(raw, 8, 0)
	if len(aligned) == 8 { pass = pass + 1 }
	if aligned[7] == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
