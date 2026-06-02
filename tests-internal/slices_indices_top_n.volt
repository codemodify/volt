package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Basic: top 3 of [10, 30, 20, 50, 40] → indices [3, 1, 4] (values 50, 30, 40 desc)
	// Wait — desc order: 50(idx 3), 40(idx 4), 30(idx 1). So [3, 4, 1].
	var s1 []int = new(5) []int {10, 30, 20, 50, 40}
	var r1 []int = slices.IndicesOfTopNInt(s1, 3)
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == 3 { pass = pass + 1 }
	if r1[1] == 4 { pass = pass + 1 }
	if r1[2] == 1 { pass = pass + 1 }

	// Empty input.
	var s2 []int = new(0) []int {}
	var r2 []int = slices.IndicesOfTopNInt(s2, 5)
	if len(r2) == 0 { pass = pass + 1 }

	// n <= 0.
	var s3 []int = new(3) []int {1, 2, 3}
	var r3 []int = slices.IndicesOfTopNInt(s3, 0)
	if len(r3) == 0 { pass = pass + 1 }
	var r3b []int = slices.IndicesOfTopNInt(s3, -1)
	if len(r3b) == 0 { pass = pass + 1 }

	// n > len(s) clamps.
	var s4 []int = new(3) []int {5, 1, 9}
	var r4 []int = slices.IndicesOfTopNInt(s4, 100)
	if len(r4) == 3 { pass = pass + 1 }
	// indices in descending order of value: 9(idx 2), 5(idx 0), 1(idx 1)
	if r4[0] == 2 { pass = pass + 1 }
	if r4[1] == 0 { pass = pass + 1 }
	if r4[2] == 1 { pass = pass + 1 }

	// Single element.
	var s5 []int = new(1) []int {42}
	var r5 []int = slices.IndicesOfTopNInt(s5, 1)
	if len(r5) == 1 { pass = pass + 1 }
	if r5[0] == 0 { pass = pass + 1 }

	// Stable tie-break: all equal → earliest indices win.
	var s6 []int = new(4) []int {7, 7, 7, 7}
	var r6 []int = slices.IndicesOfTopNInt(s6, 4)
	if r6[0] == 0 { pass = pass + 1 }
	if r6[1] == 1 { pass = pass + 1 }
	if r6[2] == 2 { pass = pass + 1 }
	if r6[3] == 3 { pass = pass + 1 }

	// Negative values + zero.
	var s7 []int = new(5) []int {-3, 0, -1, 5, -2}
	var r7 []int = slices.IndicesOfTopNInt(s7, 3)
	// desc: 5(idx 3), 0(idx 1), -1(idx 2)
	if r7[0] == 3 { pass = pass + 1 }
	if r7[1] == 1 { pass = pass + 1 }
	if r7[2] == 2 { pass = pass + 1 }

	// n == len(s) → full permutation of indices in desc order.
	var s8 []int = new(4) []int {3, 1, 4, 1}
	var r8 []int = slices.IndicesOfTopNInt(s8, 4)
	// 4(idx 2), 3(idx 0), 1(idx 1), 1(idx 3)
	if r8[0] == 2 { pass = pass + 1 }
	if r8[1] == 0 { pass = pass + 1 }
	if r8[2] == 1 { pass = pass + 1 }
	if r8[3] == 3 { pass = pass + 1 }

	// Dashboard use-case: project a parallel labels slice via the indices.
	var labels9 []string = new(4) []string {"alpha", "bravo", "charlie", "delta"}
	var counts9 []int = new(4) []int {10, 30, 20, 5}
	var idx9 []int = slices.IndicesOfTopNInt(counts9, 2)
	// Top 2 by count: 30(bravo idx 1), 20(charlie idx 2)
	if idx9[0] == 1 { pass = pass + 1 }
	if idx9[1] == 2 { pass = pass + 1 }
	if labels9[idx9[0]] == "bravo" { pass = pass + 1 }
	if labels9[idx9[1]] == "charlie" { pass = pass + 1 }

	// Doesn't mutate original.
	var s10 []int = new(3) []int {1, 5, 3}
	var _r10 []int = slices.IndicesOfTopNInt(s10, 2)
	if s10[0] == 1 { pass = pass + 1 }
	if s10[1] == 5 { pass = pass + 1 }
	if s10[2] == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 31 { ret 42 }
	ret 0
}
