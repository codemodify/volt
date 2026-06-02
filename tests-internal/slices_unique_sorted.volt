package main
import "log"
import "slices"

// Positive test: slices.UniqueSortedInt + UniqueSortedString.

fun main() int {
	var pass int = 0

	// UniqueSortedInt basic.
	var a []int = new(6) []int{3, 1, 4, 1, 5, 3}
	var us []int = slices.UniqueSortedInt(a)
	if len(us) == 4 { pass = pass + 1 }
	if us[0] == 1 { pass = pass + 1 }
	if us[1] == 3 { pass = pass + 1 }
	if us[2] == 4 { pass = pass + 1 }
	if us[3] == 5 { pass = pass + 1 }

	// All same.
	var b []int = new(4) []int{7, 7, 7, 7}
	var ub []int = slices.UniqueSortedInt(b)
	if len(ub) == 1 { pass = pass + 1 }
	if ub[0] == 7 { pass = pass + 1 }

	// All distinct.
	var c []int = new(5) []int{5, 4, 3, 2, 1}
	var uc []int = slices.UniqueSortedInt(c)
	if len(uc) == 5 { pass = pass + 1 }
	if uc[0] == 1 { pass = pass + 1 }
	if uc[4] == 5 { pass = pass + 1 }

	// Empty.
	var e []int = new(0) []int{}
	if len(slices.UniqueSortedInt(e)) == 0 { pass = pass + 1 }

	// Single.
	var sg []int = new(1) []int{42}
	var usg []int = slices.UniqueSortedInt(sg)
	if len(usg) == 1 { pass = pass + 1 }
	if usg[0] == 42 { pass = pass + 1 }

	// Negatives.
	var ne []int = new(5) []int{-3, 1, -3, 0, 1}
	var une []int = slices.UniqueSortedInt(ne)
	if len(une) == 3 { pass = pass + 1 }
	if une[0] == -3 { pass = pass + 1 }
	if une[1] == 0 { pass = pass + 1 }
	if une[2] == 1 { pass = pass + 1 }

	// Original unchanged.
	if a[0] == 3 { pass = pass + 1 }
	if a[5] == 3 { pass = pass + 1 }

	// UniqueSortedString.
	var s []string = new(5) []string{"banana", "apple", "banana", "cherry", "apple"}
	var su []string = slices.UniqueSortedString(s)
	if len(su) == 3 { pass = pass + 1 }
	if su[0] == "apple" { pass = pass + 1 }
	if su[1] == "banana" { pass = pass + 1 }
	if su[2] == "cherry" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
