package main
import "log"
import "math"

// Positive test: math.MedianOfThree + math.MidpointInt.

fun main() int {
	var pass int = 0

	// MedianOfThree — all permutations of (1, 2, 3) should return 2.
	if math.MedianOfThree(1, 2, 3) == 2 { pass = pass + 1 }
	if math.MedianOfThree(1, 3, 2) == 2 { pass = pass + 1 }
	if math.MedianOfThree(2, 1, 3) == 2 { pass = pass + 1 }
	if math.MedianOfThree(2, 3, 1) == 2 { pass = pass + 1 }
	if math.MedianOfThree(3, 1, 2) == 2 { pass = pass + 1 }
	if math.MedianOfThree(3, 2, 1) == 2 { pass = pass + 1 }

	// MedianOfThree — identical values.
	if math.MedianOfThree(5, 5, 5) == 5 { pass = pass + 1 }

	// MedianOfThree — two equal.
	if math.MedianOfThree(5, 5, 1) == 5 { pass = pass + 1 }
	if math.MedianOfThree(5, 1, 5) == 5 { pass = pass + 1 }
	if math.MedianOfThree(1, 5, 5) == 5 { pass = pass + 1 }
	if math.MedianOfThree(1, 1, 5) == 1 { pass = pass + 1 }

	// MedianOfThree — negatives.
	if math.MedianOfThree(-3, -2, -1) == -2 { pass = pass + 1 }
	if math.MedianOfThree(-10, 0, 10) == 0 { pass = pass + 1 }

	// MedianOfThree — large values.
	if math.MedianOfThree(1000000, 500000, 750000) == 750000 { pass = pass + 1 }

	// MidpointInt — basic.
	if math.MidpointInt(0, 10) == 5 { pass = pass + 1 }
	if math.MidpointInt(0, 11) == 5 { pass = pass + 1 }       // floor
	if math.MidpointInt(10, 20) == 15 { pass = pass + 1 }
	if math.MidpointInt(5, 5) == 5 { pass = pass + 1 }        // same value

	// MidpointInt — order invariant — swapping a and b might give different floor behavior on negatives.
	// For two positive values, (a+b)/2 floor is the same regardless of order.
	if math.MidpointInt(10, 20) == math.MidpointInt(20, 10) { pass = pass + 1 }
	if math.MidpointInt(7, 9) == 8 { pass = pass + 1 }

	// MidpointInt — large values that would overflow naive (a+b)/2.
	// MaxInt + MaxInt overflows; this should give (MaxInt + MaxInt-1)/2 ≈ MaxInt - 0
	if math.MidpointInt(math.MaxInt, math.MaxInt - 2) == math.MaxInt - 1 { pass = pass + 1 }
	if math.MidpointInt(math.MaxInt, math.MaxInt) == math.MaxInt { pass = pass + 1 }

	// MidpointInt — negatives.
	if math.MidpointInt(-10, 10) == 0 { pass = pass + 1 }
	if math.MidpointInt(-4, -2) == -3 { pass = pass + 1 }

	// MidpointInt — binary search style: between lo and hi-1.
	var lo int = 100
	var hi int = 200
	var mid int = math.MidpointInt(lo, hi)
	if mid >= lo { pass = pass + 1 }
	if mid < hi { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
