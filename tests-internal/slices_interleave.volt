package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// InterleaveInts — equal length.
	var a []int = new(3) []int { 1, 2, 3 }
	var b []int = new(3) []int { 10, 20, 30 }
	var r1 []int = slices.InterleaveInts(a, b)
	if len(r1) == 6 { pass = pass + 1 }
	if r1[0] == 1 { pass = pass + 1 }
	if r1[1] == 10 { pass = pass + 1 }
	if r1[2] == 2 { pass = pass + 1 }
	if r1[3] == 20 { pass = pass + 1 }
	if r1[4] == 3 { pass = pass + 1 }
	if r1[5] == 30 { pass = pass + 1 }

	// Longer first arg appends tail.
	var a2 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var b2 []int = new(2) []int { 10, 20 }
	var r2 []int = slices.InterleaveInts(a2, b2)
	if len(r2) == 7 { pass = pass + 1 }
	if r2[0] == 1 { pass = pass + 1 }
	if r2[1] == 10 { pass = pass + 1 }
	if r2[2] == 2 { pass = pass + 1 }
	if r2[3] == 20 { pass = pass + 1 }
	if r2[4] == 3 { pass = pass + 1 }     // tail starts
	if r2[6] == 5 { pass = pass + 1 }

	// Longer second arg appends tail.
	var a3 []int = new(2) []int { 1, 2 }
	var b3 []int = new(5) []int { 10, 20, 30, 40, 50 }
	var r3 []int = slices.InterleaveInts(a3, b3)
	if len(r3) == 7 { pass = pass + 1 }
	if r3[0] == 1 { pass = pass + 1 }
	if r3[1] == 10 { pass = pass + 1 }
	if r3[2] == 2 { pass = pass + 1 }
	if r3[3] == 20 { pass = pass + 1 }
	if r3[4] == 30 { pass = pass + 1 }    // tail starts
	if r3[6] == 50 { pass = pass + 1 }

	// One empty.
	var e []int = new(0) []int {}
	var some []int = new(3) []int { 5, 6, 7 }
	var r4 []int = slices.InterleaveInts(some, e)
	if len(r4) == 3 { pass = pass + 1 }
	if r4[0] == 5 { pass = pass + 1 }
	if r4[2] == 7 { pass = pass + 1 }
	var r5 []int = slices.InterleaveInts(e, some)
	if len(r5) == 3 { pass = pass + 1 }
	if r5[0] == 5 { pass = pass + 1 }

	// Both empty.
	var e2 []int = new(0) []int {}
	var r6 []int = slices.InterleaveInts(e, e2)
	if len(r6) == 0 { pass = pass + 1 }

	// InterleaveStrings.
	var sa []string = new(3) []string { "a", "b", "c" }
	var sb []string = new(3) []string { "X", "Y", "Z" }
	var rs1 []string = slices.InterleaveStrings(sa, sb)
	if len(rs1) == 6 { pass = pass + 1 }
	if rs1[0] == "a" { pass = pass + 1 }
	if rs1[1] == "X" { pass = pass + 1 }
	if rs1[2] == "b" { pass = pass + 1 }
	if rs1[5] == "Z" { pass = pass + 1 }

	// InterleaveStrings — unequal lengths.
	var sa2 []string = new(2) []string { "alpha", "beta" }
	var sb2 []string = new(4) []string { "1", "2", "3", "4" }
	var rs2 []string = slices.InterleaveStrings(sa2, sb2)
	if len(rs2) == 6 { pass = pass + 1 }
	if rs2[0] == "alpha" { pass = pass + 1 }
	if rs2[4] == "3" { pass = pass + 1 }
	if rs2[5] == "4" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 36 { ret 42 }
	ret 0
}
