package main
import "log"
import "slices"

fun absVal(x int) int {
	if x < 0 { ret -x }
	ret x
}
fun lenKey(s string) int { ret len(s) }

fun main() int {
	var pass int = 0

	// MinIndexByInt — basic, key by absolute value.
	var a []int = new(5) []int { 5, -2, 3, -1, 4 }
	if slices.MinIndexByInt(a, absVal) == 3 { pass = pass + 1 }   // -1 at idx 3

	// MaxIndexByInt.
	var b []int = new(5) []int { 1, -7, 3, -2, 4 }
	if slices.MaxIndexByInt(b, absVal) == 1 { pass = pass + 1 }   // -7 at idx 1

	// Ties → first occurrence.
	var c []int = new(4) []int { -3, 3, 3, -3 }
	if slices.MinIndexByInt(c, absVal) == 0 { pass = pass + 1 }
	if slices.MaxIndexByInt(c, absVal) == 0 { pass = pass + 1 }

	// Empty → -1.
	var empty []int = new(0) []int {}
	if slices.MinIndexByInt(empty, absVal) == -1 { pass = pass + 1 }
	if slices.MaxIndexByInt(empty, absVal) == -1 { pass = pass + 1 }

	// Single element.
	var solo []int = new(1) []int { 42 }
	if slices.MinIndexByInt(solo, absVal) == 0 { pass = pass + 1 }
	if slices.MaxIndexByInt(solo, absVal) == 0 { pass = pass + 1 }

	// MinIndexByString — by length.
	var sa []string = new(5) []string { "apple", "no", "elephant", "ok", "hi" }
	// shortest: "no" at idx 1 (first len-2 string; tie with "ok"/"hi")
	if slices.MinIndexByString(sa, lenKey) == 1 { pass = pass + 1 }
	// longest: "elephant" at idx 2.
	if slices.MaxIndexByString(sa, lenKey) == 2 { pass = pass + 1 }

	// MaxIndexByString — ties (all-same).
	var sb []string = new(3) []string { "abc", "xyz", "qrs" }
	if slices.MaxIndexByString(sb, lenKey) == 0 { pass = pass + 1 }
	if slices.MinIndexByString(sb, lenKey) == 0 { pass = pass + 1 }

	// Empty string slice.
	var se []string = new(0) []string {}
	if slices.MinIndexByString(se, lenKey) == -1 { pass = pass + 1 }
	if slices.MaxIndexByString(se, lenKey) == -1 { pass = pass + 1 }

	// MinIndexByInt agrees with MinByInt on which element.
	var d []int = new(5) []int { 5, -2, 3, -1, 4 }
	var d2 []int = new(5) []int { 5, -2, 3, -1, 4 }
	var idx int = slices.MinIndexByInt(d, absVal)
	if d2[idx] == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
