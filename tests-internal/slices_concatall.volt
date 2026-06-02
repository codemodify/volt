package main
import "log"
import "slices"

// Positive test: slices.ConcatAllInts / ConcatAllStrings — N-way
// concat over a [][]T. Leans on the LANG.8 slice-of-slice
// indexing widening.

fun main() int {
	var pass int = 0

	// Three slices concatenated.
	var a []int = new(2) []int{1, 2}
	var b []int = new(3) []int{3, 4, 5}
	var cc []int = new(1) []int{6}
	var parts1 [][]int = new(3) [][]int{a, b, cc}
	var r1 []int = slices.ConcatAllInts(parts1)
	if len(r1) == 6 { pass = pass + 1 }
	if r1[0] == 1 { pass = pass + 1 }
	if r1[2] == 3 { pass = pass + 1 }
	if r1[5] == 6 { pass = pass + 1 }

	// Single-slice "concat" — just a copy.
	var d []int = new(2) []int{10, 20}
	var parts2 [][]int = new(1) [][]int{d}
	var r2 []int = slices.ConcatAllInts(parts2)
	if len(r2) == 2 { pass = pass + 1 }
	if r2[1] == 20 { pass = pass + 1 }

	// Empty input → empty.
	var parts3 [][]int = new(0) [][]int{}
	var r3 []int = slices.ConcatAllInts(parts3)
	if len(r3) == 0 { pass = pass + 1 }

	// One of the parts is empty → still concat.
	var e []int = new(2) []int{1, 2}
	var empty []int = new(0) []int{}
	var g []int = new(1) []int{9}
	var parts4 [][]int = new(3) [][]int{e, empty, g}
	var r4 []int = slices.ConcatAllInts(parts4)
	if len(r4) == 3 { pass = pass + 1 }
	if r4[2] == 9 { pass = pass + 1 }

	// String variant.
	var sa []string = new(2) []string{"a", "b"}
	var sb []string = new(2) []string{"c", "d"}
	var sparts [][]string = new(2) [][]string{sa, sb}
	var rs []string = slices.ConcatAllStrings(sparts)
	if len(rs) == 4 { pass = pass + 1 }
	if rs[0] == "a" { pass = pass + 1 }
	if rs[3] == "d" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
