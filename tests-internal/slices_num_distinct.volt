package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → 0.
	var e []int = new(0) []int {}
	if slices.NumDistinctInt(e) == 0 { pass = pass + 1 }
	var e2 []string = new(0) []string {}
	if slices.NumDistinctString(e2) == 0 { pass = pass + 1 }

	// Single → 1.
	var s1 []int = new(1) []int { 42 }
	if slices.NumDistinctInt(s1) == 1 { pass = pass + 1 }
	var s1s []string = new(1) []string { "alice" }
	if slices.NumDistinctString(s1s) == 1 { pass = pass + 1 }

	// All distinct → len(s).
	var s2 []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.NumDistinctInt(s2) == 5 { pass = pass + 1 }

	// All same → 1.
	var s3 []int = new(5) []int { 7, 7, 7, 7, 7 }
	if slices.NumDistinctInt(s3) == 1 { pass = pass + 1 }
	var s3s []string = new(4) []string { "x", "x", "x", "x" }
	if slices.NumDistinctString(s3s) == 1 { pass = pass + 1 }

	// Mixed.
	var s4 []int = new(6) []int { 1, 2, 2, 3, 1, 4 }   // distinct: 1,2,3,4 → 4
	if slices.NumDistinctInt(s4) == 4 { pass = pass + 1 }

	var s4s []string = new(5) []string { "a", "b", "a", "c", "b" }   // a,b,c → 3
	if slices.NumDistinctString(s4s) == 3 { pass = pass + 1 }

	// With zeros & negatives.
	var s5 []int = new(6) []int { 0, -1, 0, -2, -1, 5 }   // 0,-1,-2,5 → 4
	if slices.NumDistinctInt(s5) == 4 { pass = pass + 1 }

	// Cross-property: NumDistinctInt(s) == len(UniqueInts(s)).
	var s6 []int = new(7) []int { 5, 3, 5, 1, 3, 5, 1 }
	var s6b []int = new(7) []int { 5, 3, 5, 1, 3, 5, 1 }
	var nd int = slices.NumDistinctInt(s6)
	var uq []int = slices.UniqueInts(s6b)
	if nd == len(uq) { pass = pass + 1 }

	var s7s []string = new(5) []string { "alpha", "bravo", "alpha", "charlie", "bravo" }
	var s7sb []string = new(5) []string { "alpha", "bravo", "alpha", "charlie", "bravo" }
	var nds int = slices.NumDistinctString(s7s)
	var uqs []string = slices.UniqueStrings(s7sb)
	if nds == len(uqs) { pass = pass + 1 }

	// Cross-property: NumDistinct == len(s) iff !HasDuplicates.
	var s8 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var s8b []int = new(5) []int { 1, 2, 3, 4, 5 }
	if slices.NumDistinctInt(s8) == 5 { pass = pass + 1 }
	if !slices.HasDuplicatesInt(s8b) { pass = pass + 1 }

	var s9 []int = new(5) []int { 1, 2, 3, 3, 5 }
	var s9b []int = new(5) []int { 1, 2, 3, 3, 5 }
	if slices.NumDistinctInt(s9) == 4 { pass = pass + 1 }   // < 5
	if slices.HasDuplicatesInt(s9b) { pass = pass + 1 }

	// Doesn't mutate s.
	var s10 []int = new(4) []int { 5, 3, 5, 1 }
	var _r int = slices.NumDistinctInt(s10)
	if s10[0] == 5 { pass = pass + 1 }
	if s10[1] == 3 { pass = pass + 1 }
	if s10[2] == 5 { pass = pass + 1 }
	if s10[3] == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
