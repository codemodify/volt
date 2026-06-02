package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	var e2 []int = new(0) []int {}
	var r1 []int = slices.AddVecInt(e, e2)
	if len(r1) == 0 { pass = pass + 1 }

	// One empty.
	var s1 []int = new(3) []int { 1, 2, 3 }
	var es []int = new(0) []int {}
	var r2 []int = slices.AddVecInt(s1, es)
	if len(r2) == 0 { pass = pass + 1 }

	// Add same-length.
	var a1 []int = new(4) []int { 1, 2, 3, 4 }
	var b1 []int = new(4) []int { 10, 20, 30, 40 }
	var r3 []int = slices.AddVecInt(a1, b1)
	if len(r3) == 4 { pass = pass + 1 }
	if r3[0] == 11 { pass = pass + 1 }
	if r3[1] == 22 { pass = pass + 1 }
	if r3[2] == 33 { pass = pass + 1 }
	if r3[3] == 44 { pass = pass + 1 }

	// Subtract same-length.
	var a2 []int = new(4) []int { 10, 20, 30, 40 }
	var b2 []int = new(4) []int { 1, 2, 3, 4 }
	var r4 []int = slices.SubVecInt(a2, b2)
	if r4[0] == 9 { pass = pass + 1 }
	if r4[1] == 18 { pass = pass + 1 }
	if r4[2] == 27 { pass = pass + 1 }
	if r4[3] == 36 { pass = pass + 1 }

	// Multiply same-length (Hadamard).
	var a3 []int = new(3) []int { 2, 3, 4 }
	var b3 []int = new(3) []int { 5, 6, 7 }
	var r5 []int = slices.MulVecInt(a3, b3)
	if r5[0] == 10 { pass = pass + 1 }
	if r5[1] == 18 { pass = pass + 1 }
	if r5[2] == 28 { pass = pass + 1 }

	// Mismatched length: extra tail of longer is ignored.
	var a4 []int = new(2) []int { 1, 2 }
	var b4 []int = new(5) []int { 10, 20, 999, 999, 999 }
	var r6 []int = slices.AddVecInt(a4, b4)
	if len(r6) == 2 { pass = pass + 1 }
	if r6[0] == 11 { pass = pass + 1 }
	if r6[1] == 22 { pass = pass + 1 }

	// Negative values.
	var a5 []int = new(3) []int { -5, 10, -15 }
	var b5 []int = new(3) []int { 5, -10, 15 }
	var r7 []int = slices.AddVecInt(a5, b5)
	if r7[0] == 0 { pass = pass + 1 }
	if r7[1] == 0 { pass = pass + 1 }
	if r7[2] == 0 { pass = pass + 1 }

	// Sub gives -0 = 0.
	var a6 []int = new(3) []int { 5, 5, 5 }
	var b6 []int = new(3) []int { 5, 5, 5 }
	var r8 []int = slices.SubVecInt(a6, b6)
	if r8[0] == 0 { pass = pass + 1 }
	if r8[1] == 0 { pass = pass + 1 }
	if r8[2] == 0 { pass = pass + 1 }

	// Multiply by zero → zero.
	var a7 []int = new(3) []int { 1, 2, 3 }
	var z []int = new(3) []int { 0, 0, 0 }
	var r9 []int = slices.MulVecInt(a7, z)
	if r9[0] == 0 { pass = pass + 1 }
	if r9[1] == 0 { pass = pass + 1 }
	if r9[2] == 0 { pass = pass + 1 }

	// Multiply by mask (0/1).
	var data []int = new(5) []int { 10, 20, 30, 40, 50 }
	var mask []int = new(5) []int { 1, 0, 1, 0, 1 }
	var rm []int = slices.MulVecInt(data, mask)
	if rm[0] == 10 { pass = pass + 1 }
	if rm[1] == 0 { pass = pass + 1 }
	if rm[2] == 30 { pass = pass + 1 }
	if rm[3] == 0 { pass = pass + 1 }
	if rm[4] == 50 { pass = pass + 1 }

	// Cross-property: Add then Sub identity.
	var a8 []int = new(3) []int { 7, 11, 13 }
	var b8 []int = new(3) []int { 2, 3, 5 }
	var a8b []int = new(3) []int { 7, 11, 13 }
	var sum []int = slices.AddVecInt(a8, b8)
	var got []int = slices.SubVecInt(sum, a8b)
	// got should equal b8 = [2, 3, 5]
	if got[0] == 2 { pass = pass + 1 }
	if got[1] == 3 { pass = pass + 1 }
	if got[2] == 5 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 34 { ret 42 }
	ret 0
}
