package main
import "log"
import "slices"

fun add(a int, b int) int { ret a + b }
fun mul(a int, b int) int { ret a * b }
fun maxOf(a int, b int) int {
	if a > b { ret a }
	ret b
}
fun pickA(a int, b int) int {
	if b < 0 { ret 0 }    // dead-use to satisfy checker
	ret a
}

fun main() int {
	var pass int = 0

	// Element-wise sum via ZipWithInt.
	var a []int = new(3) []int { 1, 2, 3 }
	var b []int = new(3) []int { 10, 20, 30 }
	var r1 []int = slices.ZipWithInt(a, b, add)
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == 11 { pass = pass + 1 }
	if r1[1] == 22 { pass = pass + 1 }
	if r1[2] == 33 { pass = pass + 1 }

	// Element-wise product.
	var a2 []int = new(4) []int { 2, 3, 4, 5 }
	var b2 []int = new(4) []int { 10, 10, 10, 10 }
	var r2 []int = slices.ZipWithInt(a2, b2, mul)
	if len(r2) == 4 { pass = pass + 1 }
	if r2[0] == 20 { pass = pass + 1 }
	if r2[3] == 50 { pass = pass + 1 }

	// Element-wise max.
	var a3 []int = new(4) []int { 1, 5, 3, 8 }
	var b3 []int = new(4) []int { 2, 4, 6, 7 }
	var r3 []int = slices.ZipWithInt(a3, b3, maxOf)
	if len(r3) == 4 { pass = pass + 1 }
	if r3[0] == 2 { pass = pass + 1 }
	if r3[1] == 5 { pass = pass + 1 }
	if r3[2] == 6 { pass = pass + 1 }
	if r3[3] == 8 { pass = pass + 1 }

	// Length is min of inputs.
	var a4 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var b4 []int = new(3) []int { 10, 20, 30 }
	var r4 []int = slices.ZipWithInt(a4, b4, add)
	if len(r4) == 3 { pass = pass + 1 }
	if r4[2] == 33 { pass = pass + 1 }

	// Shorter-on-left.
	var a5 []int = new(2) []int { 7, 8 }
	var b5 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var r5 []int = slices.ZipWithInt(a5, b5, add)
	if len(r5) == 2 { pass = pass + 1 }
	if r5[0] == 8 { pass = pass + 1 }
	if r5[1] == 10 { pass = pass + 1 }

	// Both empty.
	var empty1 []int = new(0) []int {}
	var empty2 []int = new(0) []int {}
	var r6 []int = slices.ZipWithInt(empty1, empty2, add)
	if len(r6) == 0 { pass = pass + 1 }

	// One empty.
	var some []int = new(3) []int { 1, 2, 3 }
	var empty3 []int = new(0) []int {}
	var r7 []int = slices.ZipWithInt(some, empty3, add)
	if len(r7) == 0 { pass = pass + 1 }

	// pickA — verify fn is the only thing combining elements.
	var a8 []int = new(3) []int { 100, 200, 300 }
	var b8 []int = new(3) []int { 1, 2, 3 }
	var r8 []int = slices.ZipWithInt(a8, b8, pickA)
	if r8[0] == 100 { pass = pass + 1 }
	if r8[2] == 300 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
