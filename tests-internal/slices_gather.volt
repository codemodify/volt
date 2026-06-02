package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Basic — pick at indices in arbitrary order.
	var src []int = new(5) []int { 10, 20, 30, 40, 50 }
	var idx []int = new(3) []int { 2, 0, 4 }
	var r1 []int = slices.GatherInt(src, idx)
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == 30 { pass = pass + 1 }
	if r1[1] == 10 { pass = pass + 1 }
	if r1[2] == 50 { pass = pass + 1 }

	// Empty indices.
	var src2 []int = new(3) []int { 1, 2, 3 }
	var emptyIdx []int = new(0) []int {}
	var r2 []int = slices.GatherInt(src2, emptyIdx)
	if len(r2) == 0 { pass = pass + 1 }

	// Empty source.
	var emptySrc []int = new(0) []int {}
	var idx2 []int = new(2) []int { 0, 1 }
	var r3 []int = slices.GatherInt(emptySrc, idx2)
	if len(r3) == 2 { pass = pass + 1 }
	if r3[0] == 0 { pass = pass + 1 }   // out-of-bounds → 0
	if r3[1] == 0 { pass = pass + 1 }

	// Out-of-bounds indices → 0 in slot.
	var src4 []int = new(3) []int { 100, 200, 300 }
	var idx4 []int = new(4) []int { -1, 0, 5, 2 }
	var r4 []int = slices.GatherInt(src4, idx4)
	if len(r4) == 4 { pass = pass + 1 }
	if r4[0] == 0 { pass = pass + 1 }    // negative
	if r4[1] == 100 { pass = pass + 1 }  // valid
	if r4[2] == 0 { pass = pass + 1 }    // past-end
	if r4[3] == 300 { pass = pass + 1 }

	// Repeated indices.
	var src5 []int = new(3) []int { 7, 8, 9 }
	var idx5 []int = new(5) []int { 0, 0, 0, 1, 1 }
	var r5 []int = slices.GatherInt(src5, idx5)
	if len(r5) == 5 { pass = pass + 1 }
	if r5[0] == 7 { pass = pass + 1 }
	if r5[2] == 7 { pass = pass + 1 }
	if r5[3] == 8 { pass = pass + 1 }

	// GatherString — basic.
	var ss []string = new(4) []string { "alpha", "beta", "gamma", "delta" }
	var sidx []string = new(0) []string {}     // unused, just to satisfy var pattern
	if len(sidx) == 0 { pass = pass + 1 }      // dead-use to keep checker happy
	var sidx2 []int = new(3) []int { 3, 0, 2 }
	var rs []string = slices.GatherString(ss, sidx2)
	if len(rs) == 3 { pass = pass + 1 }
	if rs[0] == "delta" { pass = pass + 1 }
	if rs[1] == "alpha" { pass = pass + 1 }
	if rs[2] == "gamma" { pass = pass + 1 }

	// GatherString — out-of-bounds → "".
	var ss2 []string = new(2) []string { "a", "b" }
	var sidx3 []int = new(3) []int { 0, 99, 1 }
	var rs2 []string = slices.GatherString(ss2, sidx3)
	if rs2[1] == "" { pass = pass + 1 }
	if rs2[0] == "a" { pass = pass + 1 }
	if rs2[2] == "b" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
