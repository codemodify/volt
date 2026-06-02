package main
import "log"
import "sort"

// Positive test: sort.MergeInts / MergeStrings — merge two
// pre-sorted slices into a single sorted slice.

fun main() int {
	var pass int = 0

	// Standard merge.
	var a []int = new(3) []int{1, 4, 7}
	var b []int = new(3) []int{2, 3, 8}
	var r []int = sort.MergeInts(a, b)
	if len(r) == 6 { pass = pass + 1 }
	if r[0] == 1 { pass = pass + 1 }
	if r[1] == 2 { pass = pass + 1 }
	if r[2] == 3 { pass = pass + 1 }
	if r[3] == 4 { pass = pass + 1 }
	if r[4] == 7 { pass = pass + 1 }
	if r[5] == 8 { pass = pass + 1 }

	// Disjoint ranges: a entirely before b.
	var c []int = new(2) []int{1, 2}
	var d []int = new(2) []int{10, 20}
	var r2 []int = sort.MergeInts(c, d)
	if len(r2) == 4 { pass = pass + 1 }
	if r2[1] == 2 { pass = pass + 1 }
	if r2[2] == 10 { pass = pass + 1 }

	// One empty.
	var e []int = new(0) []int{}
	var f []int = new(3) []int{5, 6, 7}
	var r3 []int = sort.MergeInts(e, f)
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == 5 { pass = pass + 1 }

	// Both empty.
	var g []int = new(0) []int{}
	var h []int = new(0) []int{}
	var r4 []int = sort.MergeInts(g, h)
	if len(r4) == 0 { pass = pass + 1 }

	// Equal elements at boundary.
	var i []int = new(3) []int{1, 2, 3}
	var j []int = new(3) []int{2, 3, 4}
	var r5 []int = sort.MergeInts(i, j)
	if len(r5) == 6 { pass = pass + 1 }
	// Result should be sorted: 1, 2, 2, 3, 3, 4
	if r5[0] == 1 { pass = pass + 1 }
	if r5[1] == 2 { pass = pass + 1 }
	if r5[5] == 4 { pass = pass + 1 }

	// MergeStrings.
	var sa []string = new(3) []string{"alpha", "delta", "echo"}
	var sb []string = new(2) []string{"bravo", "charlie"}
	var sr []string = sort.MergeStrings(sa, sb)
	if len(sr) == 5 { pass = pass + 1 }
	if sr[0] == "alpha" { pass = pass + 1 }
	if sr[1] == "bravo" { pass = pass + 1 }
	if sr[2] == "charlie" { pass = pass + 1 }
	if sr[4] == "echo" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
