package main
import "log"
import "slices"

// Positive test: slices.SortIndicesInt + SortIndicesString.

fun main() int {
	var pass int = 0

	// SortIndicesInt — basic.
	var a []int = new(5) []int{30, 10, 50, 20, 40}
	var ai []int = slices.SortIndicesInt(a)
	if len(ai) == 5 { pass = pass + 1 }
	if ai[0] == 1 { pass = pass + 1 }   // 10
	if ai[1] == 3 { pass = pass + 1 }   // 20
	if ai[2] == 0 { pass = pass + 1 }   // 30
	if ai[3] == 4 { pass = pass + 1 }   // 40
	if ai[4] == 2 { pass = pass + 1 }   // 50

	// Apply permutation to a parallel array — the values come out sorted.
	var sorted []int = new(5) []int{0, 0, 0, 0, 0}
	for i := 0; i < 5; i++ {
		sorted[i] = a[ai[i]]
	}
	if sorted[0] == 10 { pass = pass + 1 }
	if sorted[2] == 30 { pass = pass + 1 }
	if sorted[4] == 50 { pass = pass + 1 }

	// Stability — ties preserve original order.
	var b []int = new(4) []int{5, 1, 5, 1}
	var bi []int = slices.SortIndicesInt(b)
	// Sorted values: 1, 1, 5, 5; indices preserving original order: 1, 3, 0, 2.
	if bi[0] == 1 { pass = pass + 1 }
	if bi[1] == 3 { pass = pass + 1 }
	if bi[2] == 0 { pass = pass + 1 }
	if bi[3] == 2 { pass = pass + 1 }

	// Already sorted.
	var c []int = new(4) []int{1, 2, 3, 4}
	var ci []int = slices.SortIndicesInt(c)
	if ci[0] == 0 { pass = pass + 1 }
	if ci[3] == 3 { pass = pass + 1 }

	// Reverse sorted.
	var d []int = new(4) []int{4, 3, 2, 1}
	var di []int = slices.SortIndicesInt(d)
	if di[0] == 3 { pass = pass + 1 }
	if di[3] == 0 { pass = pass + 1 }

	// Empty.
	var e []int = new(0) []int{}
	var ei []int = slices.SortIndicesInt(e)
	if len(ei) == 0 { pass = pass + 1 }

	// Single.
	var sg []int = new(1) []int{42}
	var sgi []int = slices.SortIndicesInt(sg)
	if len(sgi) == 1 { pass = pass + 1 }
	if sgi[0] == 0 { pass = pass + 1 }

	// SortIndicesString — basic.
	var s []string = new(4) []string{"cherry", "apple", "date", "banana"}
	var si []int = slices.SortIndicesString(s)
	if si[0] == 1 { pass = pass + 1 }   // "apple"
	if si[1] == 3 { pass = pass + 1 }   // "banana"
	if si[2] == 0 { pass = pass + 1 }   // "cherry"
	if si[3] == 2 { pass = pass + 1 }   // "date"

	// Original not modified.
	if a[0] == 30 { pass = pass + 1 }
	if a[1] == 10 { pass = pass + 1 }
	if s[0] == "cherry" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
