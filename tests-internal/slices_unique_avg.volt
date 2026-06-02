package main
import "log"
import "slices"

// Positive test: slices.UniqueInts / UniqueStrings / AverageInt.

fun main() int {
	var pass int = 0

	// UniqueInts: preserves first-occurrence order, drops all dups.
	var a []int = new(7) []int{3, 1, 2, 1, 3, 4, 2}
	var r1 []int = slices.UniqueInts(a)
	if len(r1) == 4 { pass = pass + 1 }
	if r1[0] == 3 { pass = pass + 1 }
	if r1[1] == 1 { pass = pass + 1 }
	if r1[2] == 2 { pass = pass + 1 }
	if r1[3] == 4 { pass = pass + 1 }

	// UniqueInts: no duplicates → unchanged.
	var b []int = new(3) []int{5, 6, 7}
	var r2 []int = slices.UniqueInts(b)
	if len(r2) == 3 { pass = pass + 1 }
	if r2[2] == 7 { pass = pass + 1 }

	// UniqueInts: all same → single element.
	var c []int = new(4) []int{8, 8, 8, 8}
	var r3 []int = slices.UniqueInts(c)
	if len(r3) == 1 { pass = pass + 1 }
	if r3[0] == 8 { pass = pass + 1 }

	// UniqueInts: empty.
	var d []int = new(0) []int{}
	var r4 []int = slices.UniqueInts(d)
	if len(r4) == 0 { pass = pass + 1 }

	// UniqueStrings: drops non-adjacent duplicates too.
	var s1 []string = new(5) []string{"x", "y", "x", "z", "y"}
	var r5 []string = slices.UniqueStrings(s1)
	if len(r5) == 3 { pass = pass + 1 }
	if r5[0] == "x" { pass = pass + 1 }
	if r5[1] == "y" { pass = pass + 1 }
	if r5[2] == "z" { pass = pass + 1 }

	// AverageInt: standard case.
	var e []int = new(4) []int{1, 2, 3, 4}
	if slices.AverageInt(e) == 2 { pass = pass + 1 }   // 10/4 = 2 (truncated)

	// AverageInt: empty → 0.
	var f []int = new(0) []int{}
	if slices.AverageInt(f) == 0 { pass = pass + 1 }

	// AverageInt: single element.
	var g []int = new(1) []int{42}
	if slices.AverageInt(g) == 42 { pass = pass + 1 }

	// AverageInt: with negatives.
	var h []int = new(3) []int{-10, 0, 10}
	if slices.AverageInt(h) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
