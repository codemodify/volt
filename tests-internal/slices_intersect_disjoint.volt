package main
import "log"
import "slices"

// Positive test: slices.IntersectInt + slices.IsDisjointInt + IsDisjointString.

fun main() int {
	var pass int = 0

	// IntersectInt — basic overlap.
	var a []int = new(4) []int{1, 2, 3, 4}
	var b []int = new(4) []int{3, 4, 5, 6}
	var x []int = slices.IntersectInt(a, b)
	if len(x) == 2 { pass = pass + 1 }
	if x[0] == 3 { pass = pass + 1 }
	if x[1] == 4 { pass = pass + 1 }

	// Order from a preserved.
	var c []int = new(4) []int{10, 20, 30, 40}
	var d []int = new(4) []int{40, 30, 20, 10}
	var xcd []int = slices.IntersectInt(c, d)
	if len(xcd) == 4 { pass = pass + 1 }
	if xcd[0] == 10 { pass = pass + 1 }
	if xcd[3] == 40 { pass = pass + 1 }

	// Disjoint inputs → empty intersection.
	var e []int = new(3) []int{1, 2, 3}
	var f []int = new(3) []int{4, 5, 6}
	if len(slices.IntersectInt(e, f)) == 0 { pass = pass + 1 }

	// Duplicates in a deduped in result.
	var g []int = new(5) []int{1, 1, 2, 2, 3}
	var h []int = new(3) []int{1, 2, 3}
	var xgh []int = slices.IntersectInt(g, h)
	if len(xgh) == 3 { pass = pass + 1 }

	// Empty inputs → empty.
	var em []int = new(0) []int{}
	if len(slices.IntersectInt(em, h)) == 0 { pass = pass + 1 }
	if len(slices.IntersectInt(h, em)) == 0 { pass = pass + 1 }

	// Reflexive: Intersect(a, a) == distinct values of a.
	var u []int = new(4) []int{5, 5, 7, 7}
	var xuu []int = slices.IntersectInt(u, u)
	if len(xuu) == 2 { pass = pass + 1 }

	// IsDisjointInt.
	if slices.IsDisjointInt(e, f) { pass = pass + 1 }
	if !slices.IsDisjointInt(a, b) { pass = pass + 1 }
	if !slices.IsDisjointInt(u, u) { pass = pass + 1 }

	// Empty → vacuously disjoint.
	if slices.IsDisjointInt(em, em) { pass = pass + 1 }
	if slices.IsDisjointInt(em, a) { pass = pass + 1 }
	if slices.IsDisjointInt(a, em) { pass = pass + 1 }

	// IsDisjointString.
	var sa []string = new(3) []string{"a", "b", "c"}
	var sb []string = new(3) []string{"x", "y", "z"}
	if slices.IsDisjointString(sa, sb) { pass = pass + 1 }

	var sc []string = new(3) []string{"a", "z", "q"}
	if !slices.IsDisjointString(sa, sc) { pass = pass + 1 }   // 'a' shared

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
