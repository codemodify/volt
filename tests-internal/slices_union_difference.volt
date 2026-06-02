package main
import "log"
import "slices"

// Positive test: slices.UnionInt + slices.DifferenceInt.

fun main() int {
	var pass int = 0

	// UnionInt — overlapping inputs.
	var a []int = new(4) []int{1, 2, 3, 4}
	var b []int = new(4) []int{3, 4, 5, 6}
	var u []int = slices.UnionInt(a, b)
	if len(u) == 6 { pass = pass + 1 }
	if u[0] == 1 { pass = pass + 1 }
	if u[3] == 4 { pass = pass + 1 }   // last of a
	if u[4] == 5 { pass = pass + 1 }   // first new of b
	if u[5] == 6 { pass = pass + 1 }

	// UnionInt — disjoint.
	var c []int = new(2) []int{1, 2}
	var d []int = new(2) []int{3, 4}
	var ucd []int = slices.UnionInt(c, d)
	if len(ucd) == 4 { pass = pass + 1 }

	// UnionInt — identical inputs.
	var e []int = new(3) []int{1, 2, 3}
	var uee []int = slices.UnionInt(e, e)
	if len(uee) == 3 { pass = pass + 1 }

	// UnionInt — duplicates within a collapsed.
	var f []int = new(4) []int{1, 1, 2, 2}
	var g []int = new(2) []int{3, 3}
	var ufg []int = slices.UnionInt(f, g)
	if len(ufg) == 3 { pass = pass + 1 }

	// UnionInt — empty.
	var em []int = new(0) []int{}
	var uem []int = slices.UnionInt(em, c)
	if len(uem) == 2 { pass = pass + 1 }

	// DifferenceInt — basic.
	var dab []int = slices.DifferenceInt(a, b)
	if len(dab) == 2 { pass = pass + 1 }    // a \ b = {1, 2}
	if dab[0] == 1 { pass = pass + 1 }
	if dab[1] == 2 { pass = pass + 1 }

	// DifferenceInt — reversed.
	var dba []int = slices.DifferenceInt(b, a)
	if len(dba) == 2 { pass = pass + 1 }    // b \ a = {5, 6}
	if dba[0] == 5 { pass = pass + 1 }

	// DifferenceInt — disjoint a returns a (distinct).
	var dcd []int = slices.DifferenceInt(c, d)
	if len(dcd) == 2 { pass = pass + 1 }

	// DifferenceInt — identical inputs returns empty.
	var dee []int = slices.DifferenceInt(e, e)
	if len(dee) == 0 { pass = pass + 1 }

	// DifferenceInt — empty a returns empty.
	var dempty []int = slices.DifferenceInt(em, b)
	if len(dempty) == 0 { pass = pass + 1 }

	// DifferenceInt — empty b returns distinct a.
	var dfull []int = slices.DifferenceInt(a, em)
	if len(dfull) == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
