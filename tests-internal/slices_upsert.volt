package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty + insert.
	var e []int = new(0) []int {}
	var r1 []int = slices.UpsertInt(e, 5)
	if len(r1) == 1 { pass = pass + 1 }
	if r1[0] == 5 { pass = pass + 1 }

	// Insert new value at end.
	var s1 []int = new(3) []int { 1, 2, 3 }
	var r2 []int = slices.UpsertInt(s1, 4)
	if len(r2) == 4 { pass = pass + 1 }
	if r2[3] == 4 { pass = pass + 1 }

	// Insert already-present value → unchanged length.
	var s2 []int = new(3) []int { 1, 2, 3 }
	var r3 []int = slices.UpsertInt(s2, 2)
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == 1 { pass = pass + 1 }
	if r3[1] == 2 { pass = pass + 1 }
	if r3[2] == 3 { pass = pass + 1 }

	// First-position match.
	var s3 []int = new(3) []int { 7, 8, 9 }
	var r4 []int = slices.UpsertInt(s3, 7)
	if len(r4) == 3 { pass = pass + 1 }

	// Last-position match.
	var s4 []int = new(3) []int { 7, 8, 9 }
	var r5 []int = slices.UpsertInt(s4, 9)
	if len(r5) == 3 { pass = pass + 1 }

	// Idempotent: insert twice has same effect as once.
	var s5 []int = new(2) []int { 1, 2 }
	var s5once []int = slices.UpsertInt(s5, 3)
	var s5twice []int = slices.UpsertInt(s5once, 3)
	if len(s5twice) == 3 { pass = pass + 1 }
	if s5twice[2] == 3 { pass = pass + 1 }

	// Order preserved.
	var s6 []int = new(4) []int { 3, 1, 4, 1 }
	var r6 []int = slices.UpsertInt(s6, 5)
	if r6[0] == 3 { pass = pass + 1 }
	if r6[1] == 1 { pass = pass + 1 }
	if r6[2] == 4 { pass = pass + 1 }
	if r6[3] == 1 { pass = pass + 1 }
	if r6[4] == 5 { pass = pass + 1 }

	// String variant.
	var ss []string = new(3) []string { "alice", "bob", "carol" }
	var rs []string = slices.UpsertString(ss, "dave")
	if len(rs) == 4 { pass = pass + 1 }
	if rs[3] == "dave" { pass = pass + 1 }

	var ss2 []string = new(3) []string { "alice", "bob", "carol" }
	var rs2 []string = slices.UpsertString(ss2, "alice")
	if len(rs2) == 3 { pass = pass + 1 }

	// Doesn't mutate s.
	var s7 []int = new(3) []int { 1, 2, 3 }
	var _r []int = slices.UpsertInt(s7, 99)
	if s7[0] == 1 { pass = pass + 1 }
	if s7[1] == 2 { pass = pass + 1 }
	if s7[2] == 3 { pass = pass + 1 }

	// Cross-property: after Upsert, value is always present.
	var s8 []int = new(3) []int { 10, 20, 30 }
	var r8 []int = slices.UpsertInt(s8, 25)
	if slices.ContainsInt(r8, 25) { pass = pass + 1 }
	var s8b []int = new(3) []int { 10, 20, 30 }
	var r9 []int = slices.UpsertInt(s8b, 20)
	if slices.ContainsInt(r9, 20) { pass = pass + 1 }

	// Tag-set use case.
	var tags []string = new(0) []string {}
	tags = slices.UpsertString(tags, "urgent")
	tags = slices.UpsertString(tags, "bug")
	tags = slices.UpsertString(tags, "urgent")   // dup
	if len(tags) == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
