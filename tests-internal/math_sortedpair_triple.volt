package main
import "log"
import "math"

// Positive test: math.SortedPair + math.SortedTriple.

fun main() int {
	var pass int = 0

	var a int = 0
	var b int = 0

	// SortedPair — already sorted.
	a, b = math.SortedPair(1, 2)
	if a == 1 { pass = pass + 1 }
	if b == 2 { pass = pass + 1 }

	// SortedPair — reverse order.
	a, b = math.SortedPair(5, 3)
	if a == 3 { pass = pass + 1 }
	if b == 5 { pass = pass + 1 }

	// SortedPair — equal.
	a, b = math.SortedPair(7, 7)
	if a == 7 { pass = pass + 1 }
	if b == 7 { pass = pass + 1 }

	// SortedPair — negatives.
	a, b = math.SortedPair(-5, -10)
	if a == -10 { pass = pass + 1 }
	if b == -5 { pass = pass + 1 }

	// SortedPair — mixed sign.
	a, b = math.SortedPair(-3, 4)
	if a == -3 { pass = pass + 1 }
	if b == 4 { pass = pass + 1 }

	var lo int = 0
	var mid int = 0
	var hi int = 0

	// SortedTriple — all six permutations of (1, 2, 3) sort to (1, 2, 3).
	lo, mid, hi = math.SortedTriple(1, 2, 3)
	if lo == 1 { pass = pass + 1 }
	if mid == 2 { pass = pass + 1 }
	if hi == 3 { pass = pass + 1 }

	lo, mid, hi = math.SortedTriple(3, 1, 2)
	if lo == 1 { pass = pass + 1 }
	if mid == 2 { pass = pass + 1 }
	if hi == 3 { pass = pass + 1 }

	lo, mid, hi = math.SortedTriple(2, 3, 1)
	if lo == 1 { pass = pass + 1 }
	if mid == 2 { pass = pass + 1 }
	if hi == 3 { pass = pass + 1 }

	lo, mid, hi = math.SortedTriple(3, 2, 1)
	if lo == 1 { pass = pass + 1 }
	if mid == 2 { pass = pass + 1 }
	if hi == 3 { pass = pass + 1 }

	// SortedTriple — all equal.
	lo, mid, hi = math.SortedTriple(5, 5, 5)
	if lo == 5 { pass = pass + 1 }
	if mid == 5 { pass = pass + 1 }
	if hi == 5 { pass = pass + 1 }

	// SortedTriple — two equal.
	lo, mid, hi = math.SortedTriple(7, 3, 7)
	if lo == 3 { pass = pass + 1 }
	if mid == 7 { pass = pass + 1 }
	if hi == 7 { pass = pass + 1 }

	// SortedTriple — negatives.
	lo, mid, hi = math.SortedTriple(-5, 0, -10)
	if lo == -10 { pass = pass + 1 }
	if mid == -5 { pass = pass + 1 }
	if hi == 0 { pass = pass + 1 }

	// SortedTriple agrees with MedianOfThree on the middle.
	lo, mid, hi = math.SortedTriple(8, 3, 5)
	if mid == math.MedianOfThree(8, 3, 5) { pass = pass + 1 }
	if lo < hi { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 33 { ret 42 }
	ret 0
}
