package main
import "log"
import "slices"

// Positive test: slices.RotateInts / RotateStrings / ProductInts.

fun main() int {
	var pass int = 0

	// Left rotate by 2: [1, 2, 3, 4, 5] → [3, 4, 5, 1, 2]
	var s1 []int = new(5) []int{1, 2, 3, 4, 5}
	var r1 []int = slices.RotateInts(s1, 2)
	if r1[0] == 3 { pass = pass + 1 }
	if r1[1] == 4 { pass = pass + 1 }
	if r1[2] == 5 { pass = pass + 1 }
	if r1[3] == 1 { pass = pass + 1 }
	if r1[4] == 2 { pass = pass + 1 }

	// Right rotate by 1 (k = -1): [1, 2, 3] → [3, 1, 2]
	var s2 []int = new(3) []int{1, 2, 3}
	var r2 []int = slices.RotateInts(s2, -1)
	if r2[0] == 3 { pass = pass + 1 }
	if r2[1] == 1 { pass = pass + 1 }
	if r2[2] == 2 { pass = pass + 1 }

	// k > n: 7 % 5 = 2, equivalent to rotate-by-2.
	var s3 []int = new(5) []int{10, 20, 30, 40, 50}
	var r3 []int = slices.RotateInts(s3, 7)
	if r3[0] == 30 { pass = pass + 1 }

	// k == 0: no rotation.
	var s4 []int = new(3) []int{1, 2, 3}
	var r4 []int = slices.RotateInts(s4, 0)
	if r4[0] == 1 { pass = pass + 1 }
	if r4[2] == 3 { pass = pass + 1 }

	// Empty slice.
	var s5 []int = new(0) []int{}
	var r5 []int = slices.RotateInts(s5, 5)
	if len(r5) == 0 { pass = pass + 1 }

	// RotateStrings.
	var s6 []string = new(3) []string{"a", "b", "c"}
	var r6 []string = slices.RotateStrings(s6, 1)
	if r6[0] == "b" { pass = pass + 1 }
	if r6[1] == "c" { pass = pass + 1 }
	if r6[2] == "a" { pass = pass + 1 }

	// ProductInts.
	var s7 []int = new(4) []int{1, 2, 3, 4}
	if slices.ProductInts(s7) == 24 { pass = pass + 1 }

	// ProductInts: empty → 1.
	var s8 []int = new(0) []int{}
	if slices.ProductInts(s8) == 1 { pass = pass + 1 }

	// ProductInts: contains zero → 0.
	var s9 []int = new(3) []int{5, 0, 10}
	if slices.ProductInts(s9) == 0 { pass = pass + 1 }

	// ProductInts: contains negative.
	var s10 []int = new(3) []int{2, -3, 4}
	if slices.ProductInts(s10) == -24 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
