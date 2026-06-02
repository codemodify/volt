package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Alternating up-down-up-down.
	var v1 []int = new(5) []int {1, 5, 2, 7, 3}
	if slices.IsAlternatingInt(v1) { pass = pass + 1 }

	// Monotonic — not alternating.
	var v2 []int = new(4) []int {1, 2, 3, 4}
	if !slices.IsAlternatingInt(v2) { pass = pass + 1 }

	// Two-element direction change → alternating (vacuously).
	var v3 []int = new(2) []int {1, 5}
	if slices.IsAlternatingInt(v3) { pass = pass + 1 }

	// Equal adjacent breaks alternation.
	var v4 []int = new(4) []int {1, 5, 5, 2}
	if !slices.IsAlternatingInt(v4) { pass = pass + 1 }

	// Empty vacuously alternating.
	var v5 []int = new(0) []int {}
	if slices.IsAlternatingInt(v5) { pass = pass + 1 }

	// PeaksInt: classic single peak.
	var p1 []int = new(5) []int {1, 3, 7, 4, 2}
	var pk1 []int = slices.PeaksInt(p1)
	if len(pk1) == 1 { pass = pass + 1 }
	if pk1[0] == 2 { pass = pass + 1 }

	// Multiple peaks.
	var p2 []int = new(7) []int {1, 5, 2, 7, 3, 6, 4}
	var pk2 []int = slices.PeaksInt(p2)
	if len(pk2) == 3 { pass = pass + 1 }
	if pk2[0] == 1 { pass = pass + 1 }
	if pk2[1] == 3 { pass = pass + 1 }
	if pk2[2] == 5 { pass = pass + 1 }

	// Monotonic: no peaks.
	var p3 []int = new(4) []int {1, 2, 3, 4}
	var pk3 []int = slices.PeaksInt(p3)
	if len(pk3) == 0 { pass = pass + 1 }

	// Plateau not a peak.
	var p4 []int = new(5) []int {1, 5, 5, 5, 1}
	var pk4 []int = slices.PeaksInt(p4)
	if len(pk4) == 0 { pass = pass + 1 }

	// ValleysInt.
	var vv1 []int = new(5) []int {5, 2, 7, 3, 9}
	var va1 []int = slices.ValleysInt(vv1)
	if len(va1) == 2 { pass = pass + 1 }
	if va1[0] == 1 { pass = pass + 1 }
	if va1[1] == 3 { pass = pass + 1 }

	// Composed: PeaksInt + ValleysInt total covers the
	// "interior turning points".
	var combined []int = new(7) []int {3, 1, 4, 1, 5, 2, 6}
	var pks []int = slices.PeaksInt(combined)
	var vls []int = slices.ValleysInt(combined)
	// peaks at 2, 4, 6 (last is edge so excluded); 2, 4 only
	if len(pks) == 2 { pass = pass + 1 }
	// valleys at 1, 3, 5
	if len(vls) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
