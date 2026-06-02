package main
import "log"
import "slices"

fun isNeg(x int) bool { ret x < 0 }
fun isEven(x int) bool { ret x % 2 == 0 }
fun isLong(s string) bool {
	if len(s) > 3 { ret true }
	ret false
}

fun main() int {
	var pass int = 0

	// FindLastInt — basic.
	var a []int = new(6) []int { 1, -2, 3, -4, 5, -6 }
	var v int = 0
	var ok bool = false
	v, ok = slices.FindLastInt(a, isNeg)
	if ok { pass = pass + 1 }
	if v == -6 { pass = pass + 1 }

	// FindLastInt — single match.
	var b []int = new(4) []int { 1, 3, -7, 9 }
	v, ok = slices.FindLastInt(b, isNeg)
	if ok { pass = pass + 1 }
	if v == -7 { pass = pass + 1 }

	// FindLastInt — no match → (0, false).
	var c []int = new(3) []int { 1, 2, 3 }
	v, ok = slices.FindLastInt(c, isNeg)
	if !ok { pass = pass + 1 }
	if v == 0 { pass = pass + 1 }

	// FindLastInt — empty input.
	var d []int = new(0) []int {}
	v, ok = slices.FindLastInt(d, isNeg)
	if !ok { pass = pass + 1 }

	// FindLastInt vs FindInt — different positions when both match.
	var e []int = new(5) []int { 2, 1, 4, 1, 6 }
	var first int = 0
	var last int = 0
	first, ok = slices.FindInt(e, isEven)
	if first == 2 { pass = pass + 1 }
	last, ok = slices.FindLastInt(e, isEven)
	if last == 6 { pass = pass + 1 }

	// FindLastString — basic.
	var sa []string = new(4) []string { "hi", "hello", "yo", "greetings" }
	var sv string = ""
	var sok bool = false
	sv, sok = slices.FindLastString(sa, isLong)
	if sok { pass = pass + 1 }
	if sv == "greetings" { pass = pass + 1 }

	// FindLastString — no match.
	var sb []string = new(3) []string { "a", "bc", "de" }
	sv, sok = slices.FindLastString(sb, isLong)
	if !sok { pass = pass + 1 }
	if sv == "" { pass = pass + 1 }

	// FindLastString — empty input.
	var sc []string = new(0) []string {}
	sv, sok = slices.FindLastString(sc, isLong)
	if !sok { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
