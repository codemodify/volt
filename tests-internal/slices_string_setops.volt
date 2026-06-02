package main
import "log"
import "slices"

// Positive test: slices.IntersectString + UnionString + DifferenceString.

fun main() int {
	var pass int = 0

	var a []string = new(4) []string{"apple", "banana", "cherry", "date"}
	var b []string = new(4) []string{"cherry", "date", "elderberry", "fig"}

	// IntersectString.
	var x []string = slices.IntersectString(a, b)
	if len(x) == 2 { pass = pass + 1 }
	if x[0] == "cherry" { pass = pass + 1 }
	if x[1] == "date" { pass = pass + 1 }

	// IntersectString — disjoint.
	var d []string = new(2) []string{"x", "y"}
	if len(slices.IntersectString(a, d)) == 0 { pass = pass + 1 }

	// IntersectString — empty inputs.
	var em []string = new(0) []string{}
	if len(slices.IntersectString(em, a)) == 0 { pass = pass + 1 }
	if len(slices.IntersectString(a, em)) == 0 { pass = pass + 1 }

	// IntersectString — duplicates in a deduped.
	var ad []string = new(4) []string{"apple", "apple", "banana", "banana"}
	if len(slices.IntersectString(ad, a)) == 2 { pass = pass + 1 }

	// UnionString.
	var u []string = slices.UnionString(a, b)
	if len(u) == 6 { pass = pass + 1 }
	if u[0] == "apple" { pass = pass + 1 }
	if u[3] == "date" { pass = pass + 1 }
	if u[4] == "elderberry" { pass = pass + 1 }
	if u[5] == "fig" { pass = pass + 1 }

	// UnionString — disjoint.
	var ud []string = slices.UnionString(a, d)
	if len(ud) == 6 { pass = pass + 1 }

	// UnionString — empty.
	if len(slices.UnionString(em, em)) == 0 { pass = pass + 1 }

	// UnionString — duplicates collapsed.
	var dup1 []string = new(3) []string{"x", "x", "y"}
	var dup2 []string = new(2) []string{"y", "z"}
	if len(slices.UnionString(dup1, dup2)) == 3 { pass = pass + 1 }

	// DifferenceString — basic.
	var da []string = slices.DifferenceString(a, b)
	if len(da) == 2 { pass = pass + 1 }
	if da[0] == "apple" { pass = pass + 1 }
	if da[1] == "banana" { pass = pass + 1 }

	// DifferenceString — reversed.
	var db []string = slices.DifferenceString(b, a)
	if len(db) == 2 { pass = pass + 1 }
	if db[0] == "elderberry" { pass = pass + 1 }

	// DifferenceString — identical empties.
	if len(slices.DifferenceString(a, a)) == 0 { pass = pass + 1 }

	// DifferenceString — empty a empty.
	if len(slices.DifferenceString(em, b)) == 0 { pass = pass + 1 }

	// DifferenceString — empty b returns distinct a.
	if len(slices.DifferenceString(a, em)) == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
