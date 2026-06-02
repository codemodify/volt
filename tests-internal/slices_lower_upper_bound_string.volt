package main
import "log"
import "slices"

// Positive test: slices.LowerBoundString + slices.UpperBoundString.

fun main() int {
	var pass int = 0

	// LowerBoundString — basic sorted.
	var s1 []string = new(5) []string { "apple", "banana", "cherry", "date", "elderberry" }
	if slices.LowerBoundString(s1, "cherry") == 2 { pass = pass + 1 }
	if slices.LowerBoundString(s1, "chia") == 3 { pass = pass + 1 }       // between cherry and date
	if slices.LowerBoundString(s1, "aardvark") == 0 { pass = pass + 1 }   // before all
	if slices.LowerBoundString(s1, "zebra") == 5 { pass = pass + 1 }      // past all
	if slices.LowerBoundString(s1, "apple") == 0 { pass = pass + 1 }
	if slices.LowerBoundString(s1, "elderberry") == 4 { pass = pass + 1 }

	// LowerBoundString — duplicates → leftmost.
	var s2 []string = new(6) []string { "a", "b", "b", "b", "c", "d" }
	if slices.LowerBoundString(s2, "b") == 1 { pass = pass + 1 }
	if slices.LowerBoundString(s2, "c") == 4 { pass = pass + 1 }

	// LowerBoundString — empty.
	var emptyS []string = new(0) []string {}
	if slices.LowerBoundString(emptyS, "x") == 0 { pass = pass + 1 }

	// UpperBoundString — basic sorted.
	if slices.UpperBoundString(s1, "cherry") == 3 { pass = pass + 1 }
	if slices.UpperBoundString(s1, "chia") == 3 { pass = pass + 1 }
	if slices.UpperBoundString(s1, "aardvark") == 0 { pass = pass + 1 }
	if slices.UpperBoundString(s1, "zebra") == 5 { pass = pass + 1 }
	if slices.UpperBoundString(s1, "apple") == 1 { pass = pass + 1 }
	if slices.UpperBoundString(s1, "elderberry") == 5 { pass = pass + 1 }

	// UpperBoundString — duplicates → rightmost-equivalent.
	if slices.UpperBoundString(s2, "b") == 4 { pass = pass + 1 }
	if slices.UpperBoundString(s2, "c") == 5 { pass = pass + 1 }

	// UpperBoundString — empty.
	if slices.UpperBoundString(emptyS, "x") == 0 { pass = pass + 1 }

	// Frequency identity.
	if slices.UpperBoundString(s2, "b") - slices.LowerBoundString(s2, "b") == 3 { pass = pass + 1 }
	if slices.UpperBoundString(s2, "a") - slices.LowerBoundString(s2, "a") == 1 { pass = pass + 1 }
	if slices.UpperBoundString(s2, "zz") - slices.LowerBoundString(s2, "zz") == 0 { pass = pass + 1 }

	// BinarySearchString consistency.
	var pos int = 0
	var found bool = false
	pos, found = slices.BinarySearchString(s2, "c")
	if pos == slices.LowerBoundString(s2, "c") { pass = pass + 1 }
	if found { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
