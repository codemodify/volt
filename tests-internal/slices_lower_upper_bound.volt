package main
import "log"
import "slices"

// Positive test: slices.LowerBoundInt + slices.UpperBoundInt.

fun main() int {
	var pass int = 0

	// LowerBoundInt — basic on sorted distinct.
	var s1 []int = new(5) []int { 1, 3, 5, 7, 9 }
	if slices.LowerBoundInt(s1, 5) == 2 { pass = pass + 1 }
	if slices.LowerBoundInt(s1, 6) == 3 { pass = pass + 1 }      // insertion before 7
	if slices.LowerBoundInt(s1, 0) == 0 { pass = pass + 1 }      // before all
	if slices.LowerBoundInt(s1, 100) == 5 { pass = pass + 1 }    // past all
	if slices.LowerBoundInt(s1, 1) == 0 { pass = pass + 1 }      // first
	if slices.LowerBoundInt(s1, 9) == 4 { pass = pass + 1 }      // last

	// LowerBoundInt — with duplicates returns leftmost of equal range.
	var s2 []int = new(7) []int { 1, 2, 2, 2, 3, 4, 5 }
	if slices.LowerBoundInt(s2, 2) == 1 { pass = pass + 1 }
	if slices.LowerBoundInt(s2, 3) == 4 { pass = pass + 1 }

	// LowerBoundInt — empty slice.
	var emptyS []int = new(0) []int {}
	if slices.LowerBoundInt(emptyS, 5) == 0 { pass = pass + 1 }

	// UpperBoundInt — basic on sorted distinct.
	if slices.UpperBoundInt(s1, 5) == 3 { pass = pass + 1 }      // past 5
	if slices.UpperBoundInt(s1, 6) == 3 { pass = pass + 1 }
	if slices.UpperBoundInt(s1, 0) == 0 { pass = pass + 1 }
	if slices.UpperBoundInt(s1, 100) == 5 { pass = pass + 1 }
	if slices.UpperBoundInt(s1, 1) == 1 { pass = pass + 1 }      // past first
	if slices.UpperBoundInt(s1, 9) == 5 { pass = pass + 1 }      // past last

	// UpperBoundInt — with duplicates returns rightmost-equivalent.
	if slices.UpperBoundInt(s2, 2) == 4 { pass = pass + 1 }
	if slices.UpperBoundInt(s2, 3) == 5 { pass = pass + 1 }

	// UpperBoundInt — empty.
	if slices.UpperBoundInt(emptyS, 5) == 0 { pass = pass + 1 }

	// Frequency identity: UpperBound - LowerBound = count.
	if slices.UpperBoundInt(s2, 2) - slices.LowerBoundInt(s2, 2) == 3 { pass = pass + 1 }
	if slices.UpperBoundInt(s2, 1) - slices.LowerBoundInt(s2, 1) == 1 { pass = pass + 1 }
	if slices.UpperBoundInt(s2, 99) - slices.LowerBoundInt(s2, 99) == 0 { pass = pass + 1 }

	// LowerBound consistent with BinarySearchInt position.
	var pos int = 0
	var found bool = false
	pos, found = slices.BinarySearchInt(s2, 3)
	if pos == slices.LowerBoundInt(s2, 3) { pass = pass + 1 }
	if found { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
