package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → (0, false).
	var e []int = new(0) []int {}
	var v0 int = 0
	var ok0 bool = false
	v0, ok0 = slices.FirstDuplicateInt(e)
	if v0 == 0 { pass = pass + 1 }
	if !ok0 { pass = pass + 1 }

	// Single element → not found.
	var s1 []int = new(1) []int { 42 }
	var v1 int = 0
	var ok1 bool = false
	v1, ok1 = slices.FirstDuplicateInt(s1)
	if v1 == 0 { pass = pass + 1 }
	if !ok1 { pass = pass + 1 }

	// All distinct → not found.
	var s2 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var v2 int = 0
	var ok2 bool = false
	v2, ok2 = slices.FirstDuplicateInt(s2)
	if v2 == 0 { pass = pass + 1 }
	if !ok2 { pass = pass + 1 }

	// One dup at end (FirstDup picks the EARLIER occurrence value).
	var s3 []int = new(5) []int { 7, 8, 9, 10, 8 }
	var v3 int = 0
	var ok3 bool = false
	v3, ok3 = slices.FirstDuplicateInt(s3)
	if ok3 { pass = pass + 1 }
	if v3 == 8 { pass = pass + 1 }

	// Adjacent dup.
	var s4 []int = new(4) []int { 1, 2, 2, 3 }
	var v4 int = 0
	var ok4 bool = false
	v4, ok4 = slices.FirstDuplicateInt(s4)
	if ok4 { pass = pass + 1 }
	if v4 == 2 { pass = pass + 1 }

	// Multiple dups — returns first one encountered.
	var s5 []int = new(6) []int { 1, 2, 3, 1, 2, 3 }
	var v5 int = 0
	var ok5 bool = false
	v5, ok5 = slices.FirstDuplicateInt(s5)
	if v5 == 1 { pass = pass + 1 }
	if ok5 { pass = pass + 1 }

	// All same.
	var s6 []int = new(4) []int { 5, 5, 5, 5 }
	var v6 int = 0
	var ok6 bool = false
	v6, ok6 = slices.FirstDuplicateInt(s6)
	if v6 == 5 { pass = pass + 1 }
	if ok6 { pass = pass + 1 }

	// Negative values.
	var s7 []int = new(4) []int { -1, -2, -3, -1 }
	var v7 int = 0
	var ok7 bool = false
	v7, ok7 = slices.FirstDuplicateInt(s7)
	if v7 == -1 { pass = pass + 1 }
	if ok7 { pass = pass + 1 }

	// Zeros.
	var s8 []int = new(3) []int { 0, 1, 0 }
	var v8 int = 0
	var ok8 bool = false
	v8, ok8 = slices.FirstDuplicateInt(s8)
	if v8 == 0 { pass = pass + 1 }
	if ok8 { pass = pass + 1 }

	// String variant.
	var ss []string = new(4) []string { "alice", "bob", "alice", "carol" }
	var sv string = ""
	var sok bool = false
	sv, sok = slices.FirstDuplicateString(ss)
	if sv == "alice" { pass = pass + 1 }
	if sok { pass = pass + 1 }

	var ss2 []string = new(3) []string { "a", "b", "c" }
	var sv2 string = ""
	var sok2 bool = false
	sv2, sok2 = slices.FirstDuplicateString(ss2)
	if sv2 == "" { pass = pass + 1 }
	if !sok2 { pass = pass + 1 }

	// Cross-property: FirstDuplicate.ok iff HasDuplicates.
	var s9 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var s9b []int = new(5) []int { 1, 2, 3, 4, 5 }
	var _v int = 0
	var fok bool = false
	_v, fok = slices.FirstDuplicateInt(s9)
	if fok == slices.HasDuplicatesInt(s9b) { pass = pass + 1 }

	var s10 []int = new(4) []int { 1, 2, 2, 4 }
	var s10b []int = new(4) []int { 1, 2, 2, 4 }
	var _v2 int = 0
	var fok2 bool = false
	_v2, fok2 = slices.FirstDuplicateInt(s10)
	if fok2 == slices.HasDuplicatesInt(s10b) { pass = pass + 1 }

	// Validation use case.
	var userIds []int = new(5) []int { 100, 200, 300, 100, 400 }
	var dupId int = 0
	var hasDup bool = false
	dupId, hasDup = slices.FirstDuplicateInt(userIds)
	if hasDup { pass = pass + 1 }
	if dupId == 100 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
