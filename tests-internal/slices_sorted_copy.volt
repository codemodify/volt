package main
import "log"
import "slices"

// Positive test: slices.SortedCopyInt + SortedDescCopyInt + SortedCopyString + SortedDescCopyString.

fun main() int {
	var pass int = 0

	// SortedCopyInt — non-destructive sort.
	var a []int = new(5) []int{3, 1, 4, 1, 5}
	var sc []int = slices.SortedCopyInt(a)
	if len(sc) == 5 { pass = pass + 1 }
	if sc[0] == 1 { pass = pass + 1 }
	if sc[1] == 1 { pass = pass + 1 }
	if sc[2] == 3 { pass = pass + 1 }
	if sc[3] == 4 { pass = pass + 1 }
	if sc[4] == 5 { pass = pass + 1 }
	// Original unchanged.
	if a[0] == 3 { pass = pass + 1 }
	if a[2] == 4 { pass = pass + 1 }

	// SortedDescCopyInt.
	var sd []int = slices.SortedDescCopyInt(a)
	if sd[0] == 5 { pass = pass + 1 }
	if sd[4] == 1 { pass = pass + 1 }
	// Original still unchanged.
	if a[0] == 3 { pass = pass + 1 }

	// Empty.
	var em []int = new(0) []int{}
	if len(slices.SortedCopyInt(em)) == 0 { pass = pass + 1 }
	if len(slices.SortedDescCopyInt(em)) == 0 { pass = pass + 1 }

	// Single.
	var sg []int = new(1) []int{42}
	var sgSorted []int = slices.SortedCopyInt(sg)
	if sgSorted[0] == 42 { pass = pass + 1 }

	// SortedCopyString.
	var s []string = new(4) []string{"banana", "apple", "cherry", "date"}
	var ss []string = slices.SortedCopyString(s)
	if ss[0] == "apple" { pass = pass + 1 }
	if ss[1] == "banana" { pass = pass + 1 }
	if ss[2] == "cherry" { pass = pass + 1 }
	if ss[3] == "date" { pass = pass + 1 }
	if s[0] == "banana" { pass = pass + 1 }   // original unchanged

	// SortedDescCopyString.
	var sds []string = slices.SortedDescCopyString(s)
	if sds[0] == "date" { pass = pass + 1 }
	if sds[3] == "apple" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
