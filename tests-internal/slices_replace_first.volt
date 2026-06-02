package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	var r1 []int = slices.ReplaceFirstInt(e, 5, 99)
	if len(r1) == 0 { pass = pass + 1 }

	// No match → verbatim copy.
	var s1 []int = new(3) []int { 1, 2, 3 }
	var r2 []int = slices.ReplaceFirstInt(s1, 99, 100)
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 1 { pass = pass + 1 }
	if r2[1] == 2 { pass = pass + 1 }
	if r2[2] == 3 { pass = pass + 1 }

	// Single occurrence replaced.
	var s2 []int = new(4) []int { 1, 2, 3, 4 }
	var r3 []int = slices.ReplaceFirstInt(s2, 3, 99)
	if r3[0] == 1 { pass = pass + 1 }
	if r3[1] == 2 { pass = pass + 1 }
	if r3[2] == 99 { pass = pass + 1 }
	if r3[3] == 4 { pass = pass + 1 }

	// Multiple occurrences — only first replaced.
	var s3 []int = new(5) []int { 1, 7, 2, 7, 3 }
	var r4 []int = slices.ReplaceFirstInt(s3, 7, 0)
	if r4[1] == 0 { pass = pass + 1 }
	if r4[3] == 7 { pass = pass + 1 }   // unchanged

	// First-position match.
	var s4 []int = new(3) []int { 5, 6, 7 }
	var r5 []int = slices.ReplaceFirstInt(s4, 5, 99)
	if r5[0] == 99 { pass = pass + 1 }
	if r5[1] == 6 { pass = pass + 1 }

	// Last-position match.
	var s5 []int = new(3) []int { 1, 2, 3 }
	var r6 []int = slices.ReplaceFirstInt(s5, 3, 99)
	if r6[2] == 99 { pass = pass + 1 }

	// old == repl → unchanged.
	var s6 []int = new(3) []int { 1, 2, 3 }
	var r7 []int = slices.ReplaceFirstInt(s6, 2, 2)
	if r7[1] == 2 { pass = pass + 1 }

	// Doesn't mutate s.
	var s7 []int = new(3) []int { 1, 2, 3 }
	var _r []int = slices.ReplaceFirstInt(s7, 2, 99)
	if s7[0] == 1 { pass = pass + 1 }
	if s7[1] == 2 { pass = pass + 1 }
	if s7[2] == 3 { pass = pass + 1 }

	// String variant.
	var ss []string = new(3) []string { "alice", "bob", "carol" }
	var rs []string = slices.ReplaceFirstString(ss, "bob", "dave")
	if rs[0] == "alice" { pass = pass + 1 }
	if rs[1] == "dave" { pass = pass + 1 }
	if rs[2] == "carol" { pass = pass + 1 }

	// String: multiple, only first.
	var ss2 []string = new(4) []string { "a", "b", "a", "c" }
	var rs2 []string = slices.ReplaceFirstString(ss2, "a", "X")
	if rs2[0] == "X" { pass = pass + 1 }
	if rs2[2] == "a" { pass = pass + 1 }   // not replaced

	// Cross-property: ReplaceAllInt with single occurrence == ReplaceFirstInt.
	var s8 []int = new(4) []int { 1, 2, 3, 4 }
	var s8b []int = new(4) []int { 1, 2, 3, 4 }
	var r8 []int = slices.ReplaceFirstInt(s8, 3, 99)
	var r9 []int = slices.ReplaceAllInt(s8b, 3, 99)
	var same bool = true
	if r8[0] != r9[0] { same = false }
	if r8[1] != r9[1] { same = false }
	if r8[2] != r9[2] { same = false }
	if r8[3] != r9[3] { same = false }
	if same { pass = pass + 1 }

	// Update one record use case.
	var ids []int = new(5) []int { 100, 200, 300, 400, 500 }
	var updated []int = slices.ReplaceFirstInt(ids, 300, 350)
	if updated[2] == 350 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
