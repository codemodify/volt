package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []string = new(0) []string {}
	var r1 []string = slices.TrimLeftString(e, "")
	if len(r1) == 0 { pass = pass + 1 }
	var e2 []string = new(0) []string {}
	var r2 []string = slices.TrimRightString(e2, "")
	if len(r2) == 0 { pass = pass + 1 }
	var e3 []string = new(0) []string {}
	var r3 []string = slices.TrimString(e3, "")
	if len(r3) == 0 { pass = pass + 1 }

	// No match → copy.
	var s1 []string = new(3) []string { "a", "b", "c" }
	var r4 []string = slices.TrimLeftString(s1, "z")
	if len(r4) == 3 { pass = pass + 1 }
	if r4[0] == "a" { pass = pass + 1 }
	if r4[2] == "c" { pass = pass + 1 }

	// Leading empty strings stripped.
	var s2 []string = new(6) []string { "", "", "", "hello", "world", "x" }
	var r5 []string = slices.TrimLeftString(s2, "")
	if len(r5) == 3 { pass = pass + 1 }
	if r5[0] == "hello" { pass = pass + 1 }
	if r5[1] == "world" { pass = pass + 1 }
	if r5[2] == "x" { pass = pass + 1 }

	// Trailing empty strings stripped.
	var s3 []string = new(6) []string { "alpha", "beta", "", "", "", "" }
	var r6 []string = slices.TrimRightString(s3, "")
	if len(r6) == 2 { pass = pass + 1 }
	if r6[0] == "alpha" { pass = pass + 1 }
	if r6[1] == "beta" { pass = pass + 1 }

	// Both ends.
	var s4 []string = new(7) []string { "", "", "x", "y", "z", "", "" }
	var r7 []string = slices.TrimString(s4, "")
	if len(r7) == 3 { pass = pass + 1 }
	if r7[0] == "x" { pass = pass + 1 }
	if r7[1] == "y" { pass = pass + 1 }
	if r7[2] == "z" { pass = pass + 1 }

	// All-match → empty.
	var s5 []string = new(4) []string { "skip", "skip", "skip", "skip" }
	var r8 []string = slices.TrimString(s5, "skip")
	if len(r8) == 0 { pass = pass + 1 }

	// Interior preserved.
	var s6 []string = new(7) []string { "", "a", "", "b", "", "c", "" }
	var r9 []string = slices.TrimString(s6, "")
	if len(r9) == 5 { pass = pass + 1 }
	if r9[0] == "a" { pass = pass + 1 }
	if r9[1] == "" { pass = pass + 1 }
	if r9[2] == "b" { pass = pass + 1 }
	if r9[3] == "" { pass = pass + 1 }
	if r9[4] == "c" { pass = pass + 1 }

	// Trim non-empty value.
	var s7 []string = new(5) []string { "X", "X", "data", "X", "X" }
	var r10 []string = slices.TrimString(s7, "X")
	if len(r10) == 1 { pass = pass + 1 }
	if r10[0] == "data" { pass = pass + 1 }

	// Doesn't mutate s.
	var s8 []string = new(3) []string { "z", "y", "z" }
	var _r []string = slices.TrimString(s8, "z")
	if s8[0] == "z" { pass = pass + 1 }
	if s8[1] == "y" { pass = pass + 1 }
	if s8[2] == "z" { pass = pass + 1 }

	// CSV-cell cleanup use case (strip leading/trailing blank cells).
	var row []string = new(7) []string { "", "name", "age", "email", "", "", "" }
	var trimmed []string = slices.TrimString(row, "")
	if len(trimmed) == 3 { pass = pass + 1 }
	if trimmed[0] == "name" { pass = pass + 1 }
	if trimmed[2] == "email" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
