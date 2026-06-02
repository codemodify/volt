package main
import "log"
import "slices"

// Positive test: slices.SetUnionStrings / SetIntersectionStrings /
// SetDifferenceStrings.

fun main() int {
	var pass int = 0

	var a []string = new(3) []string{"x", "y", "z"}
	var b []string = new(3) []string{"y", "z", "w"}
	var sa map[string]bool = slices.StringsToSet(a)
	var sb map[string]bool = slices.StringsToSet(b)

	// Union: x, y, z, w → 4 elements.
	var u map[string]bool = slices.SetUnionStrings(sa, sb)
	if len(u) == 4 { pass = pass + 1 }
	if slices.SetContainsString(u, "x") { pass = pass + 1 }
	if slices.SetContainsString(u, "y") { pass = pass + 1 }
	if slices.SetContainsString(u, "w") { pass = pass + 1 }

	// Intersection: y, z → 2 elements.
	var sa2 map[string]bool = slices.StringsToSet(a)
	var sb2 map[string]bool = slices.StringsToSet(b)
	var i1 map[string]bool = slices.SetIntersectionStrings(sa2, sb2)
	if len(i1) == 2 { pass = pass + 1 }
	if slices.SetContainsString(i1, "y") { pass = pass + 1 }
	if slices.SetContainsString(i1, "z") { pass = pass + 1 }
	if !slices.SetContainsString(i1, "x") { pass = pass + 1 }

	// Difference: a - b = {x}.
	var sa3 map[string]bool = slices.StringsToSet(a)
	var sb3 map[string]bool = slices.StringsToSet(b)
	var d1 map[string]bool = slices.SetDifferenceStrings(sa3, sb3)
	if len(d1) == 1 { pass = pass + 1 }
	if slices.SetContainsString(d1, "x") { pass = pass + 1 }

	// Disjoint sets: intersection is empty.
	var c []string = new(2) []string{"p", "q"}
	var d []string = new(2) []string{"r", "s"}
	var sc map[string]bool = slices.StringsToSet(c)
	var sd map[string]bool = slices.StringsToSet(d)
	var i2 map[string]bool = slices.SetIntersectionStrings(sc, sd)
	if len(i2) == 0 { pass = pass + 1 }

	// Equal sets: difference is empty.
	var e []string = new(3) []string{"a", "b", "c"}
	var f []string = new(3) []string{"a", "b", "c"}
	var se map[string]bool = slices.StringsToSet(e)
	var sf map[string]bool = slices.StringsToSet(f)
	var d2 map[string]bool = slices.SetDifferenceStrings(se, sf)
	if len(d2) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
