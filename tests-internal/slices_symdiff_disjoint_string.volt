package main
import "log"
import "slices"

// Positive test: slices.SymmetricDifferenceString + slices.DisjointString.

fun main() int {
	var pass int = 0

	// SymDiff — basic.
	var s1 []string = slices.SymmetricDifferenceString(new(4) []string { "a", "b", "c", "d" }, new(4) []string { "c", "d", "e", "f" })
	if len(s1) == 4 { pass = pass + 1 }
	if s1[0] == "a" { pass = pass + 1 }
	if s1[1] == "b" { pass = pass + 1 }
	if s1[2] == "e" { pass = pass + 1 }
	if s1[3] == "f" { pass = pass + 1 }

	// Identical → empty.
	var s2 []string = slices.SymmetricDifferenceString(new(3) []string { "x", "y", "z" }, new(3) []string { "x", "y", "z" })
	if len(s2) == 0 { pass = pass + 1 }

	// Empty + non-empty.
	var s3 []string = slices.SymmetricDifferenceString(new(0) []string {}, new(2) []string { "a", "b" })
	if len(s3) == 2 { pass = pass + 1 }

	// Both empty.
	var s4 []string = slices.SymmetricDifferenceString(new(0) []string {}, new(0) []string {})
	if len(s4) == 0 { pass = pass + 1 }

	// Disjoint full-passthrough.
	var s5 []string = slices.SymmetricDifferenceString(new(2) []string { "a", "b" }, new(2) []string { "c", "d" })
	if len(s5) == 4 { pass = pass + 1 }

	// Duplicates deduped.
	var s6 []string = slices.SymmetricDifferenceString(new(4) []string { "a", "a", "b", "b" }, new(2) []string { "b", "c" })
	if len(s6) == 2 { pass = pass + 1 }
	if s6[0] == "a" { pass = pass + 1 }
	if s6[1] == "c" { pass = pass + 1 }

	// DisjointString — true cases.
	if slices.DisjointString(new(3) []string { "a", "b", "c" }, new(3) []string { "d", "e", "f" }) { pass = pass + 1 }
	if slices.DisjointString(new(0) []string {}, new(3) []string { "a", "b", "c" }) { pass = pass + 1 }
	if slices.DisjointString(new(0) []string {}, new(0) []string {}) { pass = pass + 1 }

	// DisjointString — false: overlap.
	if !slices.DisjointString(new(3) []string { "a", "b", "c" }, new(3) []string { "c", "d", "e" }) { pass = pass + 1 }
	if !slices.DisjointString(new(3) []string { "x", "y", "z" }, new(3) []string { "x", "y", "z" }) { pass = pass + 1 }

	// Cardinality identity.
	var a []string = new(3) []string { "a", "b", "c" }
	var b []string = new(3) []string { "b", "c", "d" }
	var dif []string = slices.SymmetricDifferenceString(a, b)
	if len(dif) == len(slices.UnionString(a, b)) - len(slices.IntersectString(a, b)) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
