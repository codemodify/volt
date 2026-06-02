package main
import "log"
import "slices"

// Positive test: slices.RemoveAtInt + RemoveAtString.

fun main() int {
	var pass int = 0

	// RemoveAtInt — middle.
	var a []int = new(5) []int{10, 20, 30, 40, 50}
	var ra []int = slices.RemoveAtInt(a, 2)
	if len(ra) == 4 { pass = pass + 1 }
	if ra[0] == 10 { pass = pass + 1 }
	if ra[1] == 20 { pass = pass + 1 }
	if ra[2] == 40 { pass = pass + 1 }
	if ra[3] == 50 { pass = pass + 1 }

	// At start.
	var rb []int = slices.RemoveAtInt(a, 0)
	if len(rb) == 4 { pass = pass + 1 }
	if rb[0] == 20 { pass = pass + 1 }

	// At end.
	var rc []int = slices.RemoveAtInt(a, 4)
	if len(rc) == 4 { pass = pass + 1 }
	if rc[3] == 40 { pass = pass + 1 }

	// Out of bounds → copy.
	var rd []int = slices.RemoveAtInt(a, 100)
	if len(rd) == 5 { pass = pass + 1 }
	if rd[0] == 10 { pass = pass + 1 }

	// Negative → copy.
	var re []int = slices.RemoveAtInt(a, -1)
	if len(re) == 5 { pass = pass + 1 }

	// Single element → empty.
	var sg []int = new(1) []int{42}
	if len(slices.RemoveAtInt(sg, 0)) == 0 { pass = pass + 1 }

	// Empty input → empty.
	var em []int = new(0) []int{}
	if len(slices.RemoveAtInt(em, 0)) == 0 { pass = pass + 1 }

	// Original unchanged.
	if a[2] == 30 { pass = pass + 1 }

	// RemoveAtString.
	var s []string = new(4) []string{"a", "b", "c", "d"}
	var rs []string = slices.RemoveAtString(s, 1)
	if len(rs) == 3 { pass = pass + 1 }
	if rs[0] == "a" { pass = pass + 1 }
	if rs[1] == "c" { pass = pass + 1 }
	if rs[2] == "d" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
