package main
import "log"
import "sort"

// Positive test: sort.IntsDesc / StringsDesc — descending sort.
// Same insertion-sort algorithm as the Asc variants with flipped
// comparison.

fun main() int {
	var pass int = 0

	// IntsDesc: standard case.
	var a []int = new(5) []int{3, 1, 4, 1, 5}
	a = sort.IntsDesc(a)
	if a[0] == 5 { pass = pass + 1 }
	if a[1] == 4 { pass = pass + 1 }
	if a[2] == 3 { pass = pass + 1 }
	if a[3] == 1 { pass = pass + 1 }
	if a[4] == 1 { pass = pass + 1 }

	// Already sorted descending.
	var b []int = new(3) []int{9, 5, 1}
	b = sort.IntsDesc(b)
	if b[0] == 9 { pass = pass + 1 }
	if b[2] == 1 { pass = pass + 1 }

	// Already sorted ascending → reverse to descending.
	var c []int = new(4) []int{1, 2, 3, 4}
	c = sort.IntsDesc(c)
	if c[0] == 4 { pass = pass + 1 }
	if c[3] == 1 { pass = pass + 1 }

	// Empty.
	var d []int = new(0) []int{}
	d = sort.IntsDesc(d)
	if len(d) == 0 { pass = pass + 1 }

	// Single element.
	var e []int = new(1) []int{42}
	e = sort.IntsDesc(e)
	if e[0] == 42 { pass = pass + 1 }

	// StringsDesc.
	var s []string = new(4) []string{"banana", "apple", "cherry", "date"}
	s = sort.StringsDesc(s)
	if s[0] == "date" { pass = pass + 1 }
	if s[1] == "cherry" { pass = pass + 1 }
	if s[2] == "banana" { pass = pass + 1 }
	if s[3] == "apple" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
