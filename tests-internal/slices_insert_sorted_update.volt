package main
import "log"
import "slices"

// Positive test: slices.InsertSortedInt + InsertSortedString + UpdateAtInt + UpdateAtString.

fun main() int {
	var pass int = 0

	// InsertSortedInt in middle.
	var a []int = new(4) []int{1, 3, 5, 7}
	var ra []int = slices.InsertSortedInt(a, 4)
	if len(ra) == 5 { pass = pass + 1 }
	if ra[0] == 1 { pass = pass + 1 }
	if ra[1] == 3 { pass = pass + 1 }
	if ra[2] == 4 { pass = pass + 1 }
	if ra[3] == 5 { pass = pass + 1 }
	if ra[4] == 7 { pass = pass + 1 }

	// Insert at start.
	var rb []int = slices.InsertSortedInt(a, 0)
	if rb[0] == 0 { pass = pass + 1 }
	if rb[1] == 1 { pass = pass + 1 }

	// Insert at end.
	var rc []int = slices.InsertSortedInt(a, 99)
	if rc[4] == 99 { pass = pass + 1 }

	// Insert duplicate.
	var rd []int = slices.InsertSortedInt(a, 5)
	if len(rd) == 5 { pass = pass + 1 }
	if rd[2] == 5 { pass = pass + 1 }   // duplicate inserted before existing 5
	if rd[3] == 5 { pass = pass + 1 }

	// Empty input.
	var em []int = new(0) []int{}
	var rem []int = slices.InsertSortedInt(em, 42)
	if len(rem) == 1 { pass = pass + 1 }
	if rem[0] == 42 { pass = pass + 1 }

	// Original unchanged.
	if a[0] == 1 { pass = pass + 1 }
	if a[3] == 7 { pass = pass + 1 }

	// InsertSortedString.
	var s []string = new(3) []string{"apple", "cherry", "fig"}
	var rs []string = slices.InsertSortedString(s, "banana")
	if rs[0] == "apple" { pass = pass + 1 }
	if rs[1] == "banana" { pass = pass + 1 }
	if rs[2] == "cherry" { pass = pass + 1 }
	if rs[3] == "fig" { pass = pass + 1 }

	// UpdateAtInt in bounds.
	var u []int = new(3) []int{10, 20, 30}
	u = slices.UpdateAtInt(u, 1, 99)
	if u[1] == 99 { pass = pass + 1 }
	if u[0] == 10 { pass = pass + 1 }
	if u[2] == 30 { pass = pass + 1 }

	// UpdateAtInt out of bounds — no-op.
	u = slices.UpdateAtInt(u, 100, 0)
	if u[1] == 99 { pass = pass + 1 }   // still 99
	u = slices.UpdateAtInt(u, -1, 0)
	if u[1] == 99 { pass = pass + 1 }

	// UpdateAtString.
	var w []string = new(2) []string{"hi", "there"}
	w = slices.UpdateAtString(w, 0, "hey")
	if w[0] == "hey" { pass = pass + 1 }
	if w[1] == "there" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
