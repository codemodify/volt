package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// FirstInt — populated slice.
	var ints []int = new(4) []int { 10, 20, 30, 40 }
	var v int = 0
	var ok bool = false
	v, ok = slices.FirstInt(ints)
	if ok { pass = pass + 1 }
	if v == 10 { pass = pass + 1 }

	// LastInt — populated slice.
	v, ok = slices.LastInt(ints)
	if ok { pass = pass + 1 }
	if v == 40 { pass = pass + 1 }

	// Single element — first and last identical.
	var solo []int = new(1) []int { 99 }
	v, ok = slices.FirstInt(solo)
	if v == 99 { pass = pass + 1 }
	v, ok = slices.LastInt(solo)
	if v == 99 { pass = pass + 1 }

	// Empty — (0, false).
	var empty []int = new(0) []int {}
	v, ok = slices.FirstInt(empty)
	if !ok { pass = pass + 1 }
	if v == 0 { pass = pass + 1 }
	v, ok = slices.LastInt(empty)
	if !ok { pass = pass + 1 }
	if v == 0 { pass = pass + 1 }

	// FirstString — populated.
	var strs []string = new(3) []string { "apple", "banana", "cherry" }
	var s string = ""
	var sok bool = false
	s, sok = slices.FirstString(strs)
	if sok { pass = pass + 1 }
	if s == "apple" { pass = pass + 1 }

	// LastString — populated.
	s, sok = slices.LastString(strs)
	if sok { pass = pass + 1 }
	if s == "cherry" { pass = pass + 1 }

	// FirstString — empty.
	var ss []string = new(0) []string {}
	s, sok = slices.FirstString(ss)
	if !sok { pass = pass + 1 }
	if s == "" { pass = pass + 1 }

	// LastString — empty.
	s, sok = slices.LastString(ss)
	if !sok { pass = pass + 1 }
	if s == "" { pass = pass + 1 }

	// Empty-string element distinguishable from absent — ok=true.
	var sblank []string = new(1) []string { "" }
	s, sok = slices.FirstString(sblank)
	if sok { pass = pass + 1 }
	if s == "" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
