package main
import "log"
import "sort"

fun lessAsc(a int, b int) bool { ret a < b }
fun lessDesc(a int, b int) bool { ret a > b }
fun lessByAbs(a int, b int) bool {
	var aa int = a
	if aa < 0 { aa = -aa }
	var bb int = b
	if bb < 0 { bb = -bb }
	ret aa < bb
}
fun lessLen(a string, b string) bool {
	ret len(a) < len(b)
}
fun lessStrAsc(a string, b string) bool {
	var n int = len(a)
	if len(b) < n { n = len(b) }
	for i := 0; i < n; i++ {
		var ai int = a[i] & 255
		var bi int = b[i] & 255
		if ai < bi { ret true }
		if ai > bi { ret false }
	}
	ret len(a) < len(b)
}

fun main() int {
	var pass int = 0

	// IntsAreSortedBy — empty / single trivially sorted.
	var empty []int = new(0) []int {}
	if sort.IntsAreSortedBy(empty, lessAsc) { pass = pass + 1 }
	var solo []int = new(1) []int { 42 }
	if sort.IntsAreSortedBy(solo, lessAsc) { pass = pass + 1 }

	// Ascending: lessAsc returns true.
	var asc []int = new(4) []int { 1, 2, 3, 4 }
	if sort.IntsAreSortedBy(asc, lessAsc) { pass = pass + 1 }
	// Same sequence is NOT sorted descending.
	if !sort.IntsAreSortedBy(asc, lessDesc) { pass = pass + 1 }

	// Descending.
	var desc []int = new(4) []int { 4, 3, 2, 1 }
	if sort.IntsAreSortedBy(desc, lessDesc) { pass = pass + 1 }
	if !sort.IntsAreSortedBy(desc, lessAsc) { pass = pass + 1 }

	// Equal-valued sequence is sorted under both <  and > (no inversion).
	var equal []int = new(3) []int { 7, 7, 7 }
	if sort.IntsAreSortedBy(equal, lessAsc) { pass = pass + 1 }
	if sort.IntsAreSortedBy(equal, lessDesc) { pass = pass + 1 }

	// Custom: sorted-by-absolute-value.
	var byAbs []int = new(5) []int { 1, -2, 3, -4, 5 }
	if sort.IntsAreSortedBy(byAbs, lessByAbs) { pass = pass + 1 }
	// But not sorted ascending by raw value (-2 < 1 fails).
	if !sort.IntsAreSortedBy(byAbs, lessAsc) { pass = pass + 1 }

	// StringsAreSortedBy — by length.
	var byLen []string = new(4) []string { "a", "bb", "ccc", "dddd" }
	if sort.StringsAreSortedBy(byLen, lessLen) { pass = pass + 1 }

	// Lexicographic.
	var lex []string = new(3) []string { "apple", "banana", "cherry" }
	if sort.StringsAreSortedBy(lex, lessStrAsc) { pass = pass + 1 }

	// Not lex-sorted.
	var unsorted []string = new(3) []string { "banana", "apple", "cherry" }
	if !sort.StringsAreSortedBy(unsorted, lessStrAsc) { pass = pass + 1 }

	// Empty strings slice trivially sorted.
	var sempty []string = new(0) []string {}
	if sort.StringsAreSortedBy(sempty, lessStrAsc) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
