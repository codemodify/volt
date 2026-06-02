// Pass 759 stdlib additions: slices.HammingDistanceInt /
// JaccardIndexPctInt / IsPermutationInt.
package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// HammingDistanceInt: equal slices → 0.
	var a []int = new(4) []int {1, 2, 3, 4}
	var b []int = new(4) []int {1, 2, 3, 4}
	if slices.HammingDistanceInt(a, b) == 0 { pass = pass + 1 }

	// Two differing positions.
	var c []int = new(4) []int {1, 9, 3, 8}
	if slices.HammingDistanceInt(a, c) == 2 { pass = pass + 1 }

	// Unequal lengths: surplus tail counts as differences.
	var d []int = new(6) []int {1, 2, 3, 4, 5, 6}
	if slices.HammingDistanceInt(a, d) == 2 { pass = pass + 1 }   // 4 equal + 2 surplus

	// JaccardIndexPctInt.
	var e []int = new(3) []int {1, 2, 3}
	var f []int = new(3) []int {2, 3, 4}
	// intersection {2,3}=2, union {1,2,3,4}=4 → 50
	if slices.JaccardIndexPctInt(e, f) == 50 { pass = pass + 1 }
	// identical sets → 100
	if slices.JaccardIndexPctInt(e, e) == 100 { pass = pass + 1 }
	// disjoint → 0
	var g []int = new(2) []int {7, 8}
	if slices.JaccardIndexPctInt(e, g) == 0 { pass = pass + 1 }
	// both empty → 100
	var empty []int = new(0) []int {}
	if slices.JaccardIndexPctInt(empty, empty) == 100 { pass = pass + 1 }

	// IsPermutationInt.
	var p1 []int = new(4) []int {1, 2, 2, 3}
	var p2 []int = new(4) []int {3, 2, 1, 2}
	if slices.IsMultisetEqualInt(p1, p2) { pass = pass + 1 }
	// same elements, different multiplicity → not a permutation
	var p3 []int = new(4) []int {1, 2, 3, 3}
	if !slices.IsMultisetEqualInt(p1, p3) { pass = pass + 1 }
	// different length → false
	var p4 []int = new(3) []int {1, 2, 2}
	if !slices.IsMultisetEqualInt(p1, p4) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
