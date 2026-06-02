package main
import "log"
import "slices"

// Positive test: slices.MaxIndexInt + MinIndexInt + MaxIndexString + MinIndexString.

fun main() int {
	var pass int = 0

	// MaxIndexInt — single max.
	var a []int = new(5) []int{3, 1, 7, 4, 2}
	if slices.MaxIndexInt(a) == 2 { pass = pass + 1 }
	if slices.MinIndexInt(a) == 1 { pass = pass + 1 }

	// Max at start.
	var b []int = new(4) []int{10, 5, 3, 1}
	if slices.MaxIndexInt(b) == 0 { pass = pass + 1 }
	if slices.MinIndexInt(b) == 3 { pass = pass + 1 }

	// Max at end.
	var c []int = new(4) []int{1, 2, 3, 99}
	if slices.MaxIndexInt(c) == 3 { pass = pass + 1 }
	if slices.MinIndexInt(c) == 0 { pass = pass + 1 }

	// Ties — first occurrence wins.
	var d []int = new(5) []int{5, 5, 5, 5, 5}
	if slices.MaxIndexInt(d) == 0 { pass = pass + 1 }
	if slices.MinIndexInt(d) == 0 { pass = pass + 1 }

	var e []int = new(4) []int{2, 9, 9, 2}
	if slices.MaxIndexInt(e) == 1 { pass = pass + 1 }
	if slices.MinIndexInt(e) == 0 { pass = pass + 1 }

	// Single element.
	var sg []int = new(1) []int{42}
	if slices.MaxIndexInt(sg) == 0 { pass = pass + 1 }
	if slices.MinIndexInt(sg) == 0 { pass = pass + 1 }

	// Empty → -1.
	var em []int = new(0) []int{}
	if slices.MaxIndexInt(em) == -1 { pass = pass + 1 }
	if slices.MinIndexInt(em) == -1 { pass = pass + 1 }

	// Negatives.
	var ne []int = new(5) []int{-3, -1, -7, -4, -2}
	if slices.MaxIndexInt(ne) == 1 { pass = pass + 1 }   // -1 largest
	if slices.MinIndexInt(ne) == 2 { pass = pass + 1 }   // -7 smallest

	// MaxIndexString / MinIndexString.
	var s []string = new(4) []string{"banana", "apple", "cherry", "date"}
	if slices.MaxIndexString(s) == 3 { pass = pass + 1 }   // "date" lex-greatest
	if slices.MinIndexString(s) == 1 { pass = pass + 1 }   // "apple" lex-smallest

	// String ties.
	var st []string = new(3) []string{"x", "x", "x"}
	if slices.MaxIndexString(st) == 0 { pass = pass + 1 }
	if slices.MinIndexString(st) == 0 { pass = pass + 1 }

	// String empty.
	var se []string = new(0) []string{}
	if slices.MaxIndexString(se) == -1 { pass = pass + 1 }
	if slices.MinIndexString(se) == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
