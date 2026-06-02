package main
import "log"
import "slices"

// Positive test: slices.DropInts + slices.DropStrings.

fun main() int {
	var pass int = 0

	// DropInts — basic.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	var da []int = slices.DropInts(a, 2)
	if len(da) == 3 { pass = pass + 1 }
	if da[0] == 3 { pass = pass + 1 }
	if da[1] == 4 { pass = pass + 1 }
	if da[2] == 5 { pass = pass + 1 }

	// Drop 0 → copy of s.
	var d0 []int = slices.DropInts(a, 0)
	if len(d0) == 5 { pass = pass + 1 }
	if d0[0] == 1 { pass = pass + 1 }
	if d0[4] == 5 { pass = pass + 1 }

	// Drop negative → copy of s.
	var dn []int = slices.DropInts(a, -1)
	if len(dn) == 5 { pass = pass + 1 }

	// Drop equal to len → empty.
	var de []int = slices.DropInts(a, 5)
	if len(de) == 0 { pass = pass + 1 }

	// Drop greater than len → empty.
	var dg []int = slices.DropInts(a, 100)
	if len(dg) == 0 { pass = pass + 1 }

	// Drop all but last.
	var dl []int = slices.DropInts(a, 4)
	if len(dl) == 1 { pass = pass + 1 }
	if dl[0] == 5 { pass = pass + 1 }

	// Empty input.
	var e []int = new(0) []int{}
	var ee []int = slices.DropInts(e, 3)
	if len(ee) == 0 { pass = pass + 1 }

	// Pagination: Head + Drop should partition the slice exactly.
	var h []int = slices.HeadInts(a, 2)
	if (len(h) + len(da)) == 5 { pass = pass + 1 }

	// DropStrings — basic.
	var s []string = new(4) []string{"a", "b", "c", "d"}
	var ds []string = slices.DropStrings(s, 1)
	if len(ds) == 3 { pass = pass + 1 }
	if ds[0] == "b" { pass = pass + 1 }
	if ds[2] == "d" { pass = pass + 1 }

	// DropStrings drop 0.
	var ds0 []string = slices.DropStrings(s, 0)
	if len(ds0) == 4 { pass = pass + 1 }
	if ds0[0] == "a" { pass = pass + 1 }

	// DropStrings drop all.
	var dsa []string = slices.DropStrings(s, 4)
	if len(dsa) == 0 { pass = pass + 1 }

	// Original not mutated.
	if a[0] == 1 { pass = pass + 1 }
	if s[0] == "a" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
