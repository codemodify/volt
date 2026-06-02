// Pass 758 stdlib additions: slices.DedupAdjacentInt / DedupAdjacentString
// / CountRunsInt / ZipSumInt.
package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// DedupAdjacentInt: [1,1,2,2,2,1,3,3] → [1,2,1,3]
	var s1 []int = new(8) []int {1, 1, 2, 2, 2, 1, 3, 3}
	var d1 []int = slices.DedupAdjacentInt(s1)
	if len(d1) == 4 { pass = pass + 1 }
	if d1[0] == 1 && d1[1] == 2 && d1[2] == 1 && d1[3] == 3 { pass = pass + 1 }

	// No consecutive dups → unchanged length.
	var s2 []int = new(4) []int {5, 6, 7, 8}
	var d2 []int = slices.DedupAdjacentInt(s2)
	if len(d2) == 4 { pass = pass + 1 }

	// All same → single element.
	var s3 []int = new(5) []int {9, 9, 9, 9, 9}
	var d3 []int = slices.DedupAdjacentInt(s3)
	if len(d3) == 1 { pass = pass + 1 }
	if d3[0] == 9 { pass = pass + 1 }

	// Empty → empty.
	var s4 []int = new(0) []int {}
	var d4 []int = slices.DedupAdjacentInt(s4)
	if len(d4) == 0 { pass = pass + 1 }

	// CountRunsInt agrees with DedupAdjacentInt length.
	if slices.CountRunsInt(s1) == 4 { pass = pass + 1 }
	if slices.CountRunsInt(s3) == 1 { pass = pass + 1 }
	if slices.CountRunsInt(s4) == 0 { pass = pass + 1 }

	// DedupAdjacentString.
	var ss []string = new(5) []string {"a", "a", "b", "c", "c"}
	var ds []string = slices.DedupAdjacentString(ss)
	if len(ds) == 3 { pass = pass + 1 }
	if ds[0] == "a" && ds[1] == "b" && ds[2] == "c" { pass = pass + 1 }

	// ZipSumInt: [1,2,3] + [10,20,30,40] → [11,22,33] (min length)
	var a []int = new(3) []int {1, 2, 3}
	var b []int = new(4) []int {10, 20, 30, 40}
	var z []int = slices.ZipSumInt(a, b)
	if len(z) == 3 { pass = pass + 1 }
	if z[0] == 11 && z[1] == 22 && z[2] == 33 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
