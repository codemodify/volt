package main
import "log"
import "slices"

// Positive test: slices.BinarySearchInt / BinarySearchString.
// Returns (index, found) — index is where v is, or where it would
// be inserted to keep the slice sorted.

fun main() int {
	var pass int = 0

	// Found: middle element.
	var s1 []int = new(5) []int{10, 20, 30, 40, 50}
	var i1 int = 0
	var f1 bool = false
	i1, f1 = slices.BinarySearchInt(s1, 30)
	if f1 { pass = pass + 1 }
	if i1 == 2 { pass = pass + 1 }

	// Found: first element.
	var s2 []int = new(5) []int{10, 20, 30, 40, 50}
	var i2 int = 0
	var f2 bool = false
	i2, f2 = slices.BinarySearchInt(s2, 10)
	if f2 { pass = pass + 1 }
	if i2 == 0 { pass = pass + 1 }

	// Found: last element.
	var s3 []int = new(5) []int{10, 20, 30, 40, 50}
	var i3 int = 0
	var f3 bool = false
	i3, f3 = slices.BinarySearchInt(s3, 50)
	if f3 { pass = pass + 1 }
	if i3 == 4 { pass = pass + 1 }

	// Not found: insertion position in middle.
	var s4 []int = new(5) []int{10, 20, 30, 40, 50}
	var i4 int = 0
	var f4 bool = false
	i4, f4 = slices.BinarySearchInt(s4, 25)
	if !f4 { pass = pass + 1 }
	if i4 == 2 { pass = pass + 1 }   // would insert between 20 and 30

	// Not found: smaller than all → insert at 0.
	var s5 []int = new(3) []int{10, 20, 30}
	var i5 int = 0
	var f5 bool = false
	i5, f5 = slices.BinarySearchInt(s5, 5)
	if !f5 { pass = pass + 1 }
	if i5 == 0 { pass = pass + 1 }

	// Not found: larger than all → insert at len.
	var s6 []int = new(3) []int{10, 20, 30}
	var i6 int = 0
	var f6 bool = false
	i6, f6 = slices.BinarySearchInt(s6, 100)
	if !f6 { pass = pass + 1 }
	if i6 == 3 { pass = pass + 1 }

	// Empty slice → not found, insertion at 0.
	var s7 []int = new(0) []int{}
	var i7 int = 0
	var f7 bool = false
	i7, f7 = slices.BinarySearchInt(s7, 42)
	if !f7 { pass = pass + 1 }
	if i7 == 0 { pass = pass + 1 }

	// BinarySearchString variant.
	var s8 []string = new(4) []string{"apple", "banana", "cherry", "date"}
	var i8 int = 0
	var f8 bool = false
	i8, f8 = slices.BinarySearchString(s8, "cherry")
	if f8 { pass = pass + 1 }
	if i8 == 2 { pass = pass + 1 }

	// BinarySearchString: not found.
	var s9 []string = new(3) []string{"apple", "cherry", "date"}
	var i9 int = 0
	var f9 bool = false
	i9, f9 = slices.BinarySearchString(s9, "banana")
	if !f9 { pass = pass + 1 }
	if i9 == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
