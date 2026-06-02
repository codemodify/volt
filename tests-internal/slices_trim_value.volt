package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	var r1 []int = slices.TrimLeftInt(e, 0)
	if len(r1) == 0 { pass = pass + 1 }
	var e2 []int = new(0) []int {}
	var r2 []int = slices.TrimRightInt(e2, 0)
	if len(r2) == 0 { pass = pass + 1 }
	var e3 []int = new(0) []int {}
	var r3 []int = slices.TrimInt(e3, 0)
	if len(r3) == 0 { pass = pass + 1 }

	// No match → copy.
	var s1 []int = new(3) []int { 1, 2, 3 }
	var r4 []int = slices.TrimLeftInt(s1, 0)
	if len(r4) == 3 { pass = pass + 1 }
	if r4[0] == 1 { pass = pass + 1 }
	if r4[2] == 3 { pass = pass + 1 }

	// Leading zeros stripped.
	var s2 []int = new(6) []int { 0, 0, 0, 5, 6, 7 }
	var r5 []int = slices.TrimLeftInt(s2, 0)
	if len(r5) == 3 { pass = pass + 1 }
	if r5[0] == 5 { pass = pass + 1 }
	if r5[1] == 6 { pass = pass + 1 }
	if r5[2] == 7 { pass = pass + 1 }

	// Trailing zeros stripped.
	var s3 []int = new(6) []int { 5, 6, 7, 0, 0, 0 }
	var r6 []int = slices.TrimRightInt(s3, 0)
	if len(r6) == 3 { pass = pass + 1 }
	if r6[0] == 5 { pass = pass + 1 }
	if r6[2] == 7 { pass = pass + 1 }

	// Both ends stripped.
	var s4 []int = new(8) []int { 0, 0, 5, 6, 7, 0, 0, 0 }
	var r7 []int = slices.TrimInt(s4, 0)
	if len(r7) == 3 { pass = pass + 1 }
	if r7[0] == 5 { pass = pass + 1 }
	if r7[1] == 6 { pass = pass + 1 }
	if r7[2] == 7 { pass = pass + 1 }

	// All-match → empty.
	var s5 []int = new(4) []int { 0, 0, 0, 0 }
	var r8 []int = slices.TrimLeftInt(s5, 0)
	if len(r8) == 0 { pass = pass + 1 }
	var s5b []int = new(4) []int { 0, 0, 0, 0 }
	var r9 []int = slices.TrimRightInt(s5b, 0)
	if len(r9) == 0 { pass = pass + 1 }
	var s5c []int = new(4) []int { 0, 0, 0, 0 }
	var r10 []int = slices.TrimInt(s5c, 0)
	if len(r10) == 0 { pass = pass + 1 }

	// Interior values preserved.
	var s6 []int = new(7) []int { 0, 1, 0, 2, 0, 3, 0 }
	var r11 []int = slices.TrimInt(s6, 0)
	if len(r11) == 5 { pass = pass + 1 }
	if r11[0] == 1 { pass = pass + 1 }
	if r11[1] == 0 { pass = pass + 1 }   // interior 0 preserved
	if r11[2] == 2 { pass = pass + 1 }
	if r11[3] == 0 { pass = pass + 1 }
	if r11[4] == 3 { pass = pass + 1 }

	// Trim non-zero value.
	var s7 []int = new(5) []int { -1, -1, 5, -1, -1 }
	var r12 []int = slices.TrimInt(s7, -1)
	if len(r12) == 1 { pass = pass + 1 }
	if r12[0] == 5 { pass = pass + 1 }

	// Doesn't mutate s.
	var s8 []int = new(3) []int { 0, 5, 0 }
	var _r []int = slices.TrimInt(s8, 0)
	if s8[0] == 0 { pass = pass + 1 }
	if s8[1] == 5 { pass = pass + 1 }
	if s8[2] == 0 { pass = pass + 1 }

	// Cross-property: TrimInt(s, v) == TrimRight(TrimLeft(s, v), v).
	var s9 []int = new(7) []int { 0, 0, 1, 2, 3, 0, 0 }
	var s9b []int = new(7) []int { 0, 0, 1, 2, 3, 0, 0 }
	var ti []int = slices.TrimInt(s9, 0)
	var tl []int = slices.TrimLeftInt(s9b, 0)
	var tlr []int = slices.TrimRightInt(tl, 0)
	if len(ti) == len(tlr) { pass = pass + 1 }
	if ti[0] == tlr[0] { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 33 { ret 42 }
	ret 0
}
