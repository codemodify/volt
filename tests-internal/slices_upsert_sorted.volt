package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	var r1 []int = slices.UpsertSortedInt(e, 5)
	if len(r1) == 1 { pass = pass + 1 }
	if r1[0] == 5 { pass = pass + 1 }

	// Insert into sorted.
	var s1 []int = new(3) []int { 1, 3, 5 }
	var r2 []int = slices.UpsertSortedInt(s1, 4)
	if len(r2) == 4 { pass = pass + 1 }
	if r2[0] == 1 { pass = pass + 1 }
	if r2[1] == 3 { pass = pass + 1 }
	if r2[2] == 4 { pass = pass + 1 }
	if r2[3] == 5 { pass = pass + 1 }

	// Already present → unchanged length.
	var s2 []int = new(3) []int { 1, 3, 5 }
	var r3 []int = slices.UpsertSortedInt(s2, 3)
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == 1 { pass = pass + 1 }
	if r3[1] == 3 { pass = pass + 1 }
	if r3[2] == 5 { pass = pass + 1 }

	// Insert at start.
	var s3 []int = new(3) []int { 5, 7, 9 }
	var r4 []int = slices.UpsertSortedInt(s3, 1)
	if r4[0] == 1 { pass = pass + 1 }
	if r4[1] == 5 { pass = pass + 1 }
	if r4[3] == 9 { pass = pass + 1 }

	// Insert at end.
	var s4 []int = new(3) []int { 1, 2, 3 }
	var r5 []int = slices.UpsertSortedInt(s4, 99)
	if r5[3] == 99 { pass = pass + 1 }
	if len(r5) == 4 { pass = pass + 1 }

	// Idempotent: insert twice has same effect as once.
	var s5 []int = new(2) []int { 1, 5 }
	var s5once []int = slices.UpsertSortedInt(s5, 3)
	var s5twice []int = slices.UpsertSortedInt(s5once, 3)
	if len(s5twice) == 3 { pass = pass + 1 }

	// String variant.
	var ss []string = new(3) []string { "alice", "bob", "dave" }
	var rs []string = slices.UpsertSortedString(ss, "carol")
	if len(rs) == 4 { pass = pass + 1 }
	if rs[0] == "alice" { pass = pass + 1 }
	if rs[1] == "bob" { pass = pass + 1 }
	if rs[2] == "carol" { pass = pass + 1 }
	if rs[3] == "dave" { pass = pass + 1 }

	var ss2 []string = new(3) []string { "alice", "bob", "carol" }
	var rs2 []string = slices.UpsertSortedString(ss2, "alice")
	if len(rs2) == 3 { pass = pass + 1 }

	// Doesn't mutate s.
	var s6 []int = new(3) []int { 1, 2, 3 }
	var _r []int = slices.UpsertSortedInt(s6, 99)
	if s6[0] == 1 { pass = pass + 1 }
	if s6[1] == 2 { pass = pass + 1 }
	if s6[2] == 3 { pass = pass + 1 }

	// Cross-property: result is always sorted.
	var s7 []int = new(4) []int { 10, 20, 30, 40 }
	var r7 []int = slices.UpsertSortedInt(s7, 25)
	if slices.IsStrictlyIncreasingInt(r7) { pass = pass + 1 }

	// Sorted unique-IDs use case.
	var ids []int = new(0) []int {}
	ids = slices.UpsertSortedInt(ids, 30)
	ids = slices.UpsertSortedInt(ids, 10)
	ids = slices.UpsertSortedInt(ids, 20)
	ids = slices.UpsertSortedInt(ids, 10)   // dup
	if len(ids) == 3 { pass = pass + 1 }
	if ids[0] == 10 { pass = pass + 1 }
	if ids[1] == 20 { pass = pass + 1 }
	if ids[2] == 30 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 31 { ret 42 }
	ret 0
}
