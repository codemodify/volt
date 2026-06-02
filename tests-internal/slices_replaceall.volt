package main
import "log"
import "slices"

// Positive test: slices.ReplaceAllInt + slices.ReplaceAllString.

fun main() int {
	var pass int = 0

	// ReplaceAllInt — typical.
	var r1 []int = slices.ReplaceAllInt(new(5) []int { 1, 2, 1, 3, 1 }, 1, 9)
	if len(r1) == 5 { pass = pass + 1 }
	if r1[0] == 9 { pass = pass + 1 }
	if r1[1] == 2 { pass = pass + 1 }
	if r1[2] == 9 { pass = pass + 1 }
	if r1[3] == 3 { pass = pass + 1 }
	if r1[4] == 9 { pass = pass + 1 }

	// ReplaceAllInt — old not present → unchanged copy.
	var r2 []int = slices.ReplaceAllInt(new(3) []int { 1, 2, 3 }, 99, 0)
	if r2[0] == 1 { pass = pass + 1 }
	if r2[1] == 2 { pass = pass + 1 }
	if r2[2] == 3 { pass = pass + 1 }

	// ReplaceAllInt — empty slice.
	var r3 []int = slices.ReplaceAllInt(new(0) []int {}, 1, 2)
	if len(r3) == 0 { pass = pass + 1 }

	// ReplaceAllInt — all elements match.
	var r4 []int = slices.ReplaceAllInt(new(3) []int { 5, 5, 5 }, 5, 7)
	if r4[0] == 7 { pass = pass + 1 }
	if r4[1] == 7 { pass = pass + 1 }
	if r4[2] == 7 { pass = pass + 1 }

	// ReplaceAllInt — sentinel-value substitution: -1 → 0.
	var r5 []int = slices.ReplaceAllInt(new(4) []int { -1, 5, -1, 7 }, -1, 0)
	if r5[0] == 0 { pass = pass + 1 }
	if r5[2] == 0 { pass = pass + 1 }

	// ReplaceAllString — typical.
	var s1 []string = slices.ReplaceAllString(new(4) []string { "a", "b", "a", "c" }, "a", "X")
	if s1[0] == "X" { pass = pass + 1 }
	if s1[1] == "b" { pass = pass + 1 }
	if s1[2] == "X" { pass = pass + 1 }
	if s1[3] == "c" { pass = pass + 1 }

	// ReplaceAllString — empty.
	var s2 []string = slices.ReplaceAllString(new(0) []string {}, "x", "y")
	if len(s2) == 0 { pass = pass + 1 }

	// ReplaceAllString — old not present.
	var s3 []string = slices.ReplaceAllString(new(2) []string { "foo", "bar" }, "baz", "qux")
	if s3[0] == "foo" { pass = pass + 1 }
	if s3[1] == "bar" { pass = pass + 1 }

	// ReplaceAllString — replace with empty string.
	var s4 []string = slices.ReplaceAllString(new(3) []string { "a", "b", "a" }, "a", "")
	if s4[0] == "" { pass = pass + 1 }
	if s4[1] == "b" { pass = pass + 1 }

	// Length preserved.
	var input []int = new(5) []int { 1, 1, 1, 1, 1 }
	var output []int = slices.ReplaceAllInt(input, 1, 9)
	if len(output) == len(input) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
