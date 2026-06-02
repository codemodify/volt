package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty input → all-pad.
	var e []string = new(0) []string {}
	var r1 []string = slices.PadLeftString(e, 3, "x")
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == "x" { pass = pass + 1 }
	if r1[2] == "x" { pass = pass + 1 }

	var e2 []string = new(0) []string {}
	var r2 []string = slices.PadRightString(e2, 3, "y")
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == "y" { pass = pass + 1 }
	if r2[2] == "y" { pass = pass + 1 }

	// n <= len → unchanged copy.
	var s1 []string = new(3) []string { "a", "b", "c" }
	var r3 []string = slices.PadLeftString(s1, 2, "z")
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == "a" { pass = pass + 1 }
	if r3[2] == "c" { pass = pass + 1 }

	// Pad-left.
	var s2 []string = new(2) []string { "X", "Y" }
	var r4 []string = slices.PadLeftString(s2, 5, "-")
	if len(r4) == 5 { pass = pass + 1 }
	if r4[0] == "-" { pass = pass + 1 }
	if r4[1] == "-" { pass = pass + 1 }
	if r4[2] == "-" { pass = pass + 1 }
	if r4[3] == "X" { pass = pass + 1 }
	if r4[4] == "Y" { pass = pass + 1 }

	// Pad-right.
	var s3 []string = new(2) []string { "X", "Y" }
	var r5 []string = slices.PadRightString(s3, 5, "-")
	if len(r5) == 5 { pass = pass + 1 }
	if r5[0] == "X" { pass = pass + 1 }
	if r5[1] == "Y" { pass = pass + 1 }
	if r5[2] == "-" { pass = pass + 1 }
	if r5[3] == "-" { pass = pass + 1 }
	if r5[4] == "-" { pass = pass + 1 }

	// Empty-string pad.
	var s4 []string = new(2) []string { "first", "second" }
	var r6 []string = slices.PadLeftString(s4, 4, "")
	if r6[0] == "" { pass = pass + 1 }
	if r6[1] == "" { pass = pass + 1 }
	if r6[2] == "first" { pass = pass + 1 }
	if r6[3] == "second" { pass = pass + 1 }

	// Doesn't mutate s.
	var s5 []string = new(2) []string { "k1", "k2" }
	var _r []string = slices.PadLeftString(s5, 4, "?")
	if s5[0] == "k1" { pass = pass + 1 }
	if s5[1] == "k2" { pass = pass + 1 }

	// Fixed-width column use case.
	var col []string = new(3) []string { "a", "b", "c" }
	var aligned []string = slices.PadRightString(col, 5, "")
	if len(aligned) == 5 { pass = pass + 1 }
	if aligned[4] == "" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 29 { ret 42 }
	ret 0
}
