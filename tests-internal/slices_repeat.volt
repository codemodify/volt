package main
import "log"
import "slices"

// Positive test: slices.RepeatInt + slices.RepeatString. Mirrors
// Go 1.23's slices.Repeat for the typed-slice surface.

fun main() int {
	var pass int = 0

	// RepeatInt: [1, 2] × 3 → [1, 2, 1, 2, 1, 2]
	var s1 []int = new(2) []int{1, 2}
	var r1 []int = slices.RepeatInt(s1, 3)
	if len(r1) == 6 { pass = pass + 1 }
	if r1[0] == 1 { pass = pass + 1 }
	if r1[1] == 2 { pass = pass + 1 }
	if r1[2] == 1 { pass = pass + 1 }
	if r1[3] == 2 { pass = pass + 1 }
	if r1[4] == 1 { pass = pass + 1 }
	if r1[5] == 2 { pass = pass + 1 }

	// RepeatInt: count == 0 → empty.
	var s2 []int = new(2) []int{1, 2}
	var r2 []int = slices.RepeatInt(s2, 0)
	if len(r2) == 0 { pass = pass + 1 }

	// RepeatInt: count < 0 → empty.
	var s3 []int = new(2) []int{1, 2}
	var r3 []int = slices.RepeatInt(s3, -1)
	if len(r3) == 0 { pass = pass + 1 }

	// RepeatInt: count == 1 → copy of s.
	var s4 []int = new(3) []int{10, 20, 30}
	var r4 []int = slices.RepeatInt(s4, 1)
	if len(r4) == 3 { pass = pass + 1 }
	if r4[2] == 30 { pass = pass + 1 }

	// RepeatInt: empty source × any count → empty.
	var s5 []int = new(0) []int{}
	var r5 []int = slices.RepeatInt(s5, 5)
	if len(r5) == 0 { pass = pass + 1 }

	// RepeatString: ["a", "b"] × 2 → ["a", "b", "a", "b"].
	var s6 []string = new(2) []string{"a", "b"}
	var r6 []string = slices.RepeatString(s6, 2)
	if len(r6) == 4 { pass = pass + 1 }
	if r6[0] == "a" { pass = pass + 1 }
	if r6[3] == "b" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
