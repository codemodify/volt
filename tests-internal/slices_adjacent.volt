package main
import "log"
import "slices"

// Positive test: slices.AdjacentDiffsInt + slices.AdjacentEqualsInt.

fun main() int {
	var pass int = 0

	// AdjacentDiffsInt basic — monotonic ascending.
	var a []int = new(5) []int{1, 2, 4, 8, 16}
	var da []int = slices.AdjacentDiffsInt(a)
	if len(da) == 4 { pass = pass + 1 }
	if da[0] == 1 { pass = pass + 1 }
	if da[1] == 2 { pass = pass + 1 }
	if da[2] == 4 { pass = pass + 1 }
	if da[3] == 8 { pass = pass + 1 }

	// Descending → negative diffs.
	var b []int = new(4) []int{10, 7, 3, 0}
	var db []int = slices.AdjacentDiffsInt(b)
	if db[0] == -3 { pass = pass + 1 }
	if db[1] == -4 { pass = pass + 1 }
	if db[2] == -3 { pass = pass + 1 }

	// Constant → zero diffs.
	var c []int = new(4) []int{5, 5, 5, 5}
	var dc []int = slices.AdjacentDiffsInt(c)
	if len(dc) == 3 { pass = pass + 1 }
	if dc[0] == 0 { pass = pass + 1 }
	if dc[2] == 0 { pass = pass + 1 }

	// Single element.
	var s []int = new(1) []int{42}
	if len(slices.AdjacentDiffsInt(s)) == 0 { pass = pass + 1 }

	// Empty.
	var e []int = new(0) []int{}
	if len(slices.AdjacentDiffsInt(e)) == 0 { pass = pass + 1 }

	// Two elements.
	var t []int = new(2) []int{3, 8}
	var dt []int = slices.AdjacentDiffsInt(t)
	if len(dt) == 1 { pass = pass + 1 }
	if dt[0] == 5 { pass = pass + 1 }

	// AdjacentEqualsInt — all distinct.
	if slices.AdjacentEqualsInt(a) == 0 { pass = pass + 1 }

	// All same.
	if slices.AdjacentEqualsInt(c) == 3 { pass = pass + 1 }

	// Some pairs.
	var f []int = new(7) []int{1, 1, 2, 2, 2, 3, 3}
	if slices.AdjacentEqualsInt(f) == 4 { pass = pass + 1 }   // (1,1), (2,2), (2,2), (3,3)

	// Empty / single.
	if slices.AdjacentEqualsInt(e) == 0 { pass = pass + 1 }
	if slices.AdjacentEqualsInt(s) == 0 { pass = pass + 1 }

	// Sum of differences telescopes to last - first.
	var x []int = new(5) []int{2, 5, 9, 14, 20}
	var dx []int = slices.AdjacentDiffsInt(x)
	var sumDiff int = slices.SumInts(dx)
	if sumDiff == 18 { pass = pass + 1 }   // 20 - 2

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
