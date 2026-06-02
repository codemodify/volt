package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	var v0 int = 0
	var l0 int = 0
	v0, l0 = slices.LongestRunValueInt(e)
	if v0 == 0 { pass = pass + 1 }
	if l0 == 0 { pass = pass + 1 }

	// Single → (s[0], 1).
	var s1 []int = new(1) []int { 42 }
	var v1 int = 0
	var l1 int = 0
	v1, l1 = slices.LongestRunValueInt(s1)
	if v1 == 42 { pass = pass + 1 }
	if l1 == 1 { pass = pass + 1 }

	// All distinct → first value, length 1.
	var s2 []int = new(5) []int { 1, 2, 3, 4, 5 }
	var v2 int = 0
	var l2 int = 0
	v2, l2 = slices.LongestRunValueInt(s2)
	if v2 == 1 { pass = pass + 1 }
	if l2 == 1 { pass = pass + 1 }

	// All same → (value, n).
	var s3 []int = new(4) []int { 7, 7, 7, 7 }
	var v3 int = 0
	var l3 int = 0
	v3, l3 = slices.LongestRunValueInt(s3)
	if v3 == 7 { pass = pass + 1 }
	if l3 == 4 { pass = pass + 1 }

	// Clear winner.
	var s4 []int = new(9) []int { 1, 2, 2, 3, 3, 3, 4, 4, 5 }
	var v4 int = 0
	var l4 int = 0
	v4, l4 = slices.LongestRunValueInt(s4)
	if v4 == 3 { pass = pass + 1 }
	if l4 == 3 { pass = pass + 1 }

	// Tie → first run's value wins.
	var s5 []int = new(8) []int { 1, 1, 1, 2, 3, 3, 3, 4 }
	var v5 int = 0
	var l5 int = 0
	v5, l5 = slices.LongestRunValueInt(s5)
	if v5 == 1 { pass = pass + 1 }
	if l5 == 3 { pass = pass + 1 }

	// Trailing run wins.
	var s6 []int = new(6) []int { 1, 2, 3, 5, 5, 5 }
	var v6 int = 0
	var l6 int = 0
	v6, l6 = slices.LongestRunValueInt(s6)
	if v6 == 5 { pass = pass + 1 }
	if l6 == 3 { pass = pass + 1 }

	// Negative + zero values.
	var s7 []int = new(6) []int { -1, -1, 0, 0, 0, -1 }
	var v7 int = 0
	var l7 int = 0
	v7, l7 = slices.LongestRunValueInt(s7)
	if v7 == 0 { pass = pass + 1 }
	if l7 == 3 { pass = pass + 1 }

	// String variant.
	var ss []string = new(7) []string { "win", "win", "loss", "win", "win", "win", "loss" }
	var sv string = ""
	var sl int = 0
	sv, sl = slices.LongestRunValueString(ss)
	if sv == "win" { pass = pass + 1 }
	if sl == 3 { pass = pass + 1 }

	var ss2 []string = new(0) []string {}
	var sv2 string = ""
	var sl2 int = 0
	sv2, sl2 = slices.LongestRunValueString(ss2)
	if sv2 == "" { pass = pass + 1 }
	if sl2 == 0 { pass = pass + 1 }

	// Cross-property: length == LongestRunInt(s).
	var s8 []int = new(9) []int { 1, 2, 2, 3, 3, 3, 4, 4, 5 }
	var s8b []int = new(9) []int { 1, 2, 2, 3, 3, 3, 4, 4, 5 }
	var _v int = 0
	var llen int = 0
	_v, llen = slices.LongestRunValueInt(s8)
	if llen == slices.LongestRunInt(s8b) { pass = pass + 1 }

	// Streak use case: longest win streak.
	var games []string = new(10) []string { "win", "win", "loss", "win", "win", "win", "win", "loss", "win", "loss" }
	var streakVal string = ""
	var streakLen int = 0
	streakVal, streakLen = slices.LongestRunValueString(games)
	if streakVal == "win" { pass = pass + 1 }
	if streakLen == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
