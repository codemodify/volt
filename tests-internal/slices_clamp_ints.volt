package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Basic: clamp [-5, 5, 15] to [0, 10] → [0, 5, 10]
	var s1 []int = new(3) []int {-5, 5, 15}
	var r1 []int = slices.ClampInts(s1, 0, 10)
	if r1[0] == 0 { pass = pass + 1 }
	if r1[1] == 5 { pass = pass + 1 }
	if r1[2] == 10 { pass = pass + 1 }

	// All in range — unchanged.
	var s2 []int = new(3) []int {3, 5, 7}
	var r2 []int = slices.ClampInts(s2, 0, 10)
	if r2[0] == 3 { pass = pass + 1 }
	if r2[1] == 5 { pass = pass + 1 }
	if r2[2] == 7 { pass = pass + 1 }

	// All below — all become lo.
	var s3 []int = new(3) []int {-100, -50, -1}
	var r3 []int = slices.ClampInts(s3, 0, 10)
	if r3[0] == 0 { pass = pass + 1 }
	if r3[1] == 0 { pass = pass + 1 }
	if r3[2] == 0 { pass = pass + 1 }

	// All above — all become hi.
	var s4 []int = new(3) []int {100, 50, 11}
	var r4 []int = slices.ClampInts(s4, 0, 10)
	if r4[0] == 10 { pass = pass + 1 }
	if r4[1] == 10 { pass = pass + 1 }
	if r4[2] == 10 { pass = pass + 1 }

	// Empty input → empty.
	var s5 []int = new(0) []int {}
	var r5 []int = slices.ClampInts(s5, 0, 10)
	if len(r5) == 0 { pass = pass + 1 }

	// Negative range.
	var s6 []int = new(3) []int {-20, -10, 0}
	var r6 []int = slices.ClampInts(s6, -15, -5)
	if r6[0] == -15 { pass = pass + 1 }
	if r6[1] == -10 { pass = pass + 1 }
	if r6[2] == -5 { pass = pass + 1 }

	// Doesn't mutate source.
	var s7 []int = new(2) []int {-100, 100}
	var _r7 []int = slices.ClampInts(s7, 0, 10)
	if s7[0] == -100 { pass = pass + 1 }
	if s7[1] == 100 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
