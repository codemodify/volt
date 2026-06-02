package main
import "log"
import "slices"

// Positive test: slices.SymmetricDifferenceInt + slices.DisjointInt.

fun main() int {
	var pass int = 0

	// SymmetricDifferenceInt — basic.
	var s1 []int = slices.SymmetricDifferenceInt(new(4) []int { 1, 2, 3, 4 }, new(4) []int { 3, 4, 5, 6 })
	// 1, 2 from a-only; 5, 6 from b-only.
	if len(s1) == 4 { pass = pass + 1 }
	if s1[0] == 1 { pass = pass + 1 }
	if s1[1] == 2 { pass = pass + 1 }
	if s1[2] == 5 { pass = pass + 1 }
	if s1[3] == 6 { pass = pass + 1 }

	// SymmetricDifferenceInt — identical sets → empty.
	var s2 []int = slices.SymmetricDifferenceInt(new(3) []int { 1, 2, 3 }, new(3) []int { 1, 2, 3 })
	if len(s2) == 0 { pass = pass + 1 }

	// SymmetricDifferenceInt — empty + non-empty.
	var s3 []int = slices.SymmetricDifferenceInt(new(0) []int {}, new(3) []int { 1, 2, 3 })
	if len(s3) == 3 { pass = pass + 1 }

	// SymmetricDifferenceInt — both empty.
	var s4 []int = slices.SymmetricDifferenceInt(new(0) []int {}, new(0) []int {})
	if len(s4) == 0 { pass = pass + 1 }

	// SymmetricDifferenceInt — disjoint sets.
	var s5 []int = slices.SymmetricDifferenceInt(new(2) []int { 1, 2 }, new(2) []int { 3, 4 })
	if len(s5) == 4 { pass = pass + 1 }

	// SymmetricDifferenceInt — duplicates in input are deduped.
	var s6 []int = slices.SymmetricDifferenceInt(new(4) []int { 1, 1, 2, 2 }, new(2) []int { 2, 3 })
	if len(s6) == 2 { pass = pass + 1 }
	if s6[0] == 1 { pass = pass + 1 }
	if s6[1] == 3 { pass = pass + 1 }

	// DisjointInt — true cases.
	if slices.DisjointInt(new(3) []int { 1, 2, 3 }, new(3) []int { 4, 5, 6 }) { pass = pass + 1 }
	if slices.DisjointInt(new(0) []int {}, new(3) []int { 1, 2, 3 }) { pass = pass + 1 }
	if slices.DisjointInt(new(0) []int {}, new(0) []int {}) { pass = pass + 1 }

	// DisjointInt — false: overlap.
	if !slices.DisjointInt(new(3) []int { 1, 2, 3 }, new(3) []int { 3, 4, 5 }) { pass = pass + 1 }
	if !slices.DisjointInt(new(2) []int { 5, 5 }, new(1) []int { 5 }) { pass = pass + 1 }
	if !slices.DisjointInt(new(3) []int { 1, 2, 3 }, new(3) []int { 1, 2, 3 }) { pass = pass + 1 }

	// SymDiff identity: |a △ b| == |a∪b| - |a∩b| (for sets without dupes).
	var symA []int = new(3) []int { 1, 2, 3 }
	var symB []int = new(3) []int { 2, 3, 4 }
	var symDiff []int = slices.SymmetricDifferenceInt(symA, symB)
	if len(symDiff) == len(slices.UnionInt(symA, symB)) - len(slices.IntersectInt(symA, symB)) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
