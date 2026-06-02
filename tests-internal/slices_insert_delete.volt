package main
import "log"
import "slices"

// Positive test: slices.InsertInt / DeleteInt / InsertString /
// DeleteString. Return new slices (volt has no in-place insert/
// delete since slices move on use).

fun main() int {
	var pass int = 0

	// InsertInt: middle position.
	var s1 []int = new(3) []int{1, 2, 4}
	var r1 []int = slices.InsertInt(s1, 2, 3)
	if len(r1) == 4 { pass = pass + 1 }
	if r1[0] == 1 { pass = pass + 1 }
	if r1[1] == 2 { pass = pass + 1 }
	if r1[2] == 3 { pass = pass + 1 }
	if r1[3] == 4 { pass = pass + 1 }

	// InsertInt: at start.
	var s2 []int = new(2) []int{2, 3}
	var r2 []int = slices.InsertInt(s2, 0, 1)
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 1 { pass = pass + 1 }
	if r2[2] == 3 { pass = pass + 1 }

	// InsertInt: at end.
	var s3 []int = new(2) []int{1, 2}
	var r3 []int = slices.InsertInt(s3, 2, 3)
	if len(r3) == 3 { pass = pass + 1 }
	if r3[2] == 3 { pass = pass + 1 }

	// DeleteInt: remove middle.
	var s4 []int = new(5) []int{10, 20, 30, 40, 50}
	var r4 []int = slices.DeleteInt(s4, 1, 4)
	if len(r4) == 2 { pass = pass + 1 }
	if r4[0] == 10 { pass = pass + 1 }
	if r4[1] == 50 { pass = pass + 1 }

	// DeleteInt: remove single element.
	var s5 []int = new(4) []int{1, 2, 3, 4}
	var r5 []int = slices.DeleteInt(s5, 1, 2)
	if len(r5) == 3 { pass = pass + 1 }
	if r5[0] == 1 { pass = pass + 1 }
	if r5[1] == 3 { pass = pass + 1 }
	if r5[2] == 4 { pass = pass + 1 }

	// DeleteInt: i >= j → copy unchanged.
	var s6 []int = new(3) []int{1, 2, 3}
	var r6 []int = slices.DeleteInt(s6, 2, 1)
	if len(r6) == 3 { pass = pass + 1 }

	// InsertString.
	var s7 []string = new(2) []string{"a", "c"}
	var r7 []string = slices.InsertString(s7, 1, "b")
	if len(r7) == 3 { pass = pass + 1 }
	if r7[1] == "b" { pass = pass + 1 }

	// DeleteString.
	var s8 []string = new(4) []string{"a", "b", "c", "d"}
	var r8 []string = slices.DeleteString(s8, 1, 3)
	if len(r8) == 2 { pass = pass + 1 }
	if r8[0] == "a" { pass = pass + 1 }
	if r8[1] == "d" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
