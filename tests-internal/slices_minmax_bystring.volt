package main
import "log"
import "slices"

fun byLen(s string) int { ret len(s) }
fun byFirstByte(s string) int {
	if len(s) == 0 { ret 0 }
	ret s[0] & 255
}

fun main() int {
	var pass int = 0

	// Empty → ("", "").
	var empty []string = new(0) []string {}
	var mn string = ""
	var mx string = ""
	mn, mx = slices.MinMaxByString(empty, byLen)
	if mn == "" { pass = pass + 1 }
	if mx == "" { pass = pass + 1 }

	// Single element.
	var solo []string = new(1) []string { "hello" }
	mn, mx = slices.MinMaxByString(solo, byLen)
	if mn == "hello" { pass = pass + 1 }
	if mx == "hello" { pass = pass + 1 }

	// By length.
	var words []string = new(5) []string { "apple", "no", "elephant", "ok", "kangaroo" }
	mn, mx = slices.MinMaxByString(words, byLen)
	if mn == "no" { pass = pass + 1 }    // shortest (len 2)
	if mx == "elephant" { pass = pass + 1 }   // longest (len 8) — first occurrence wins tie

	// Tie breaking — first-occurrence (kangaroo also len 8).
	var w2 []string = new(3) []string { "abc", "xyzwq", "fghij" }
	mn, mx = slices.MinMaxByString(w2, byLen)
	if mn == "abc" { pass = pass + 1 }
	if mx == "xyzwq" { pass = pass + 1 }    // first len-5 string

	// By first byte.
	var fb []string = new(4) []string { "zoo", "apple", "moon", "banana" }
	mn, mx = slices.MinMaxByString(fb, byFirstByte)
	if mn == "apple" { pass = pass + 1 }    // 'a' = 97
	if mx == "zoo" { pass = pass + 1 }      // 'z' = 122

	// All-same-key.
	var same []string = new(3) []string { "abc", "xyz", "qrs" }
	mn, mx = slices.MinMaxByString(same, byLen)
	if mn == "abc" { pass = pass + 1 }
	if mx == "abc" { pass = pass + 1 }      // first-tied

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
