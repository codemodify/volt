package main
import "log"
import "slices"

// Positive test: slices.FindInt + slices.FindString.

fun isPositive(x int) bool { if x > 0 { ret true }; ret false }
fun isLarge(x int) bool { if x > 100 { ret true }; ret false }
fun isEmpty(s string) bool { if len(s) == 0 { ret true }; ret false }
fun startsWithA(s string) bool {
	if len(s) == 0 { ret false }
	if s[0] == 97 { ret true }   // 'a'
	ret false
}

fun main() int {
	var pass int = 0

	// FindInt — first positive in mixed slice.
	var a []int = new(5) []int{-1, -3, 4, 7, -2}
	var v int = 0
	var ok bool = false
	v, ok = slices.FindInt(a, isPositive)
	if ok { pass = pass + 1 }
	if v == 4 { pass = pass + 1 }

	// FindInt — no match.
	var b []int = new(3) []int{1, 2, 3}
	v, ok = slices.FindInt(b, isLarge)
	if !ok { pass = pass + 1 }
	if v == 0 { pass = pass + 1 }

	// FindInt — empty.
	var e []int = new(0) []int{}
	v, ok = slices.FindInt(e, isPositive)
	if !ok { pass = pass + 1 }
	if v == 0 { pass = pass + 1 }

	// FindInt — first-only (multiple matches, returns earliest).
	var c []int = new(4) []int{-1, 5, 10, 15}
	v, ok = slices.FindInt(c, isPositive)
	if v == 5 { pass = pass + 1 }

	// FindInt — single element match.
	var s1 []int = new(1) []int{42}
	v, ok = slices.FindInt(s1, isPositive)
	if ok { pass = pass + 1 }
	if v == 42 { pass = pass + 1 }

	// FindString — empty in list.
	var s []string = new(4) []string{"hi", "yo", "", "ok"}
	var sv string = ""
	var sok bool = false
	sv, sok = slices.FindString(s, isEmpty)
	if sok { pass = pass + 1 }
	if sv == "" { pass = pass + 1 }

	// FindString — starts with 'a'.
	var t []string = new(4) []string{"bob", "alice", "carol", "alpha"}
	sv, sok = slices.FindString(t, startsWithA)
	if sok { pass = pass + 1 }
	if sv == "alice" { pass = pass + 1 }

	// FindString — no match.
	var u []string = new(3) []string{"x", "y", "z"}
	sv, sok = slices.FindString(u, startsWithA)
	if !sok { pass = pass + 1 }
	if sv == "" { pass = pass + 1 }

	// FindString — empty input.
	var ee []string = new(0) []string{}
	sv, sok = slices.FindString(ee, isEmpty)
	if !sok { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
