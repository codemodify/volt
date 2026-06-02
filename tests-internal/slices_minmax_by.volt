package main
import "log"
import "slices"

// Positive test: slices.MinByInt / MaxByInt / MinByString / MaxByString —
// key-projection min/max.

fun absInt(x int) int {
	if x < 0 { ret -x }
	ret x
}

fun negate(x int) int { ret -x }

fun strLen(s string) int { ret len(s) }

fun firstByteAsInt(s string) int {
	if len(s) == 0 { ret 0 }
	ret s[0]
}

fun main() int {
	var pass int = 0

	// MinByInt: smallest absolute value.
	var a []int = new(5) []int{-7, 2, -3, 10, -1}
	if slices.MinByInt(a, absInt) == -1 { pass = pass + 1 }

	// MaxByInt: largest absolute value.
	if slices.MaxByInt(a, absInt) == 10 { pass = pass + 1 }

	// MinByInt with negate: smallest -x == largest x (ties to first).
	var b []int = new(4) []int{3, 7, 1, 9}
	if slices.MinByInt(b, negate) == 9 { pass = pass + 1 }
	if slices.MaxByInt(b, negate) == 1 { pass = pass + 1 }

	// Ties resolve to first occurrence.
	var c []int = new(4) []int{2, -2, 2, -2}
	if slices.MinByInt(c, absInt) == 2 { pass = pass + 1 }   // |2|=|−2|=2, first wins
	if slices.MaxByInt(c, absInt) == 2 { pass = pass + 1 }   // same projection on all → first

	// Single element.
	var d []int = new(1) []int{42}
	if slices.MinByInt(d, absInt) == 42 { pass = pass + 1 }
	if slices.MaxByInt(d, absInt) == 42 { pass = pass + 1 }

	// Empty slice → 0.
	var e []int = new(0) []int{}
	if slices.MinByInt(e, absInt) == 0 { pass = pass + 1 }
	if slices.MaxByInt(e, absInt) == 0 { pass = pass + 1 }

	// MinByString / MaxByString by length.
	var s1 []string = new(4) []string{"hello", "a", "bb", "ccc"}
	if slices.MinByString(s1, strLen) == "a" { pass = pass + 1 }
	if slices.MaxByString(s1, strLen) == "hello" { pass = pass + 1 }

	// MinByString / MaxByString by first byte.
	var s2 []string = new(3) []string{"banana", "apple", "cherry"}
	if slices.MinByString(s2, firstByteAsInt) == "apple" { pass = pass + 1 }
	if slices.MaxByString(s2, firstByteAsInt) == "cherry" { pass = pass + 1 }

	// String ties to first occurrence.
	var s3 []string = new(3) []string{"ab", "cd", "ef"}
	if slices.MinByString(s3, strLen) == "ab" { pass = pass + 1 }   // all len 2, first wins

	// Empty string slice → "".
	var s4 []string = new(0) []string{}
	if slices.MinByString(s4, strLen) == "" { pass = pass + 1 }
	if slices.MaxByString(s4, strLen) == "" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
