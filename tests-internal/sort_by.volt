package main
import "log"
import "sort"

// Positive test: sort.IntsBy + sort.StringsBy — comparator-based
// insertion sort that takes a `less(a, b) bool` function value.

fun gt(a int, b int) bool { ret a > b }
fun lt(a int, b int) bool { ret a < b }
fun byLen(a string, b string) bool { ret len(a) < len(b) }

fun main() int {
	var pass int = 0

	// Ascending via lt comparator.
	var a []int = new(5) []int{3, 1, 4, 1, 5}
	a = sort.IntsBy(a, lt)
	if a[0] == 1 { pass = pass + 1 }
	if a[1] == 1 { pass = pass + 1 }
	if a[2] == 3 { pass = pass + 1 }
	if a[3] == 4 { pass = pass + 1 }
	if a[4] == 5 { pass = pass + 1 }

	// Descending via gt comparator.
	var b []int = new(5) []int{3, 1, 4, 1, 5}
	b = sort.IntsBy(b, gt)
	if b[0] == 5 { pass = pass + 1 }
	if b[1] == 4 { pass = pass + 1 }
	if b[4] == 1 { pass = pass + 1 }

	// Empty slice.
	var c []int = new(0) []int{}
	c = sort.IntsBy(c, lt)
	if len(c) == 0 { pass = pass + 1 }

	// Single-element slice.
	var d []int = new(1) []int{42}
	d = sort.IntsBy(d, lt)
	if d[0] == 42 { pass = pass + 1 }

	// StringsBy with custom byLen comparator.
	var s []string = new(4) []string{"foo", "a", "wxyz", "bb"}
	s = sort.StringsBy(s, byLen)
	if s[0] == "a" { pass = pass + 1 }
	if len(s[1]) == 2 { pass = pass + 1 }
	if len(s[2]) == 3 { pass = pass + 1 }
	if s[3] == "wxyz" { pass = pass + 1 }

	log.Println("pass=%d a0=%d s0=%s", pass, a[0], s[0])
	if pass == 14 { ret 42 }
	ret 0
}
