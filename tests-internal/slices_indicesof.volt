package main
import "log"
import "slices"

// Positive test: slices.IndicesOfInt + slices.IndicesOfString.

fun main() int {
	var pass int = 0

	// IndicesOfInt — multiple matches.
	var i1 []int = slices.IndicesOfInt(new(7) []int { 1, 2, 1, 3, 1, 4, 5 }, 1)
	if len(i1) == 3 { pass = pass + 1 }
	if i1[0] == 0 { pass = pass + 1 }
	if i1[1] == 2 { pass = pass + 1 }
	if i1[2] == 4 { pass = pass + 1 }

	// IndicesOfInt — single match.
	var i2 []int = slices.IndicesOfInt(new(5) []int { 1, 2, 3, 4, 5 }, 3)
	if len(i2) == 1 { pass = pass + 1 }
	if i2[0] == 2 { pass = pass + 1 }

	// IndicesOfInt — no match.
	var i3 []int = slices.IndicesOfInt(new(3) []int { 1, 2, 3 }, 99)
	if len(i3) == 0 { pass = pass + 1 }

	// IndicesOfInt — all match.
	var i4 []int = slices.IndicesOfInt(new(4) []int { 5, 5, 5, 5 }, 5)
	if len(i4) == 4 { pass = pass + 1 }
	if i4[3] == 3 { pass = pass + 1 }

	// IndicesOfInt — empty.
	var i5 []int = slices.IndicesOfInt(new(0) []int {}, 1)
	if len(i5) == 0 { pass = pass + 1 }

	// IndicesOfString — multiple matches.
	var s1 []int = slices.IndicesOfString(new(5) []string { "a", "b", "a", "c", "a" }, "a")
	if len(s1) == 3 { pass = pass + 1 }
	if s1[0] == 0 { pass = pass + 1 }
	if s1[2] == 4 { pass = pass + 1 }

	// IndicesOfString — no match.
	var s2 []int = slices.IndicesOfString(new(3) []string { "x", "y", "z" }, "missing")
	if len(s2) == 0 { pass = pass + 1 }

	// IndicesOfString — empty.
	var s3 []int = slices.IndicesOfString(new(0) []string {}, "x")
	if len(s3) == 0 { pass = pass + 1 }

	// Cross-check: IndicesOf length == HistogramString counts.
	var data []string = new(6) []string { "apple", "banana", "apple", "cherry", "apple", "banana" }
	if len(slices.IndicesOfString(data, "apple")) == 3 { pass = pass + 1 }
	if len(slices.IndicesOfString(data, "banana")) == 2 { pass = pass + 1 }
	if len(slices.IndicesOfString(data, "cherry")) == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
