package main
import "log"
import "math"

// Positive test: math.CeilDivInt + math.RoundDivInt.

fun main() int {
	var pass int = 0

	// CeilDivInt — exact division.
	if math.CeilDivInt(0, 5) == 0 { pass = pass + 1 }
	if math.CeilDivInt(10, 5) == 2 { pass = pass + 1 }
	if math.CeilDivInt(100, 10) == 10 { pass = pass + 1 }

	// CeilDivInt — round up.
	if math.CeilDivInt(7, 3) == 3 { pass = pass + 1 }    // ceil(7/3) = 3
	if math.CeilDivInt(1, 5) == 1 { pass = pass + 1 }    // ceil(1/5) = 1
	if math.CeilDivInt(11, 5) == 3 { pass = pass + 1 }   // ceil(11/5) = 3
	if math.CeilDivInt(9, 4) == 3 { pass = pass + 1 }    // ceil(9/4) = 3

	// CeilDivInt — pagination example.
	if math.CeilDivInt(101, 25) == 5 { pass = pass + 1 }   // 5 pages for 101 items @ 25/page
	if math.CeilDivInt(100, 25) == 4 { pass = pass + 1 }

	// CeilDivInt — invalid.
	if math.CeilDivInt(10, 0) == 0 { pass = pass + 1 }
	if math.CeilDivInt(10, -3) == 0 { pass = pass + 1 }
	if math.CeilDivInt(-5, 3) == 0 { pass = pass + 1 }

	// RoundDivInt — exact.
	if math.RoundDivInt(0, 5) == 0 { pass = pass + 1 }
	if math.RoundDivInt(10, 5) == 2 { pass = pass + 1 }

	// RoundDivInt — round down (< .5).
	if math.RoundDivInt(7, 3) == 2 { pass = pass + 1 }   // 7/3 = 2.33 → 2
	if math.RoundDivInt(9, 4) == 2 { pass = pass + 1 }   // 9/4 = 2.25 → 2

	// RoundDivInt — round up (>= .5).
	if math.RoundDivInt(8, 3) == 3 { pass = pass + 1 }   // 8/3 = 2.66 → 3
	if math.RoundDivInt(11, 4) == 3 { pass = pass + 1 }  // 11/4 = 2.75 → 3
	if math.RoundDivInt(10, 4) == 3 { pass = pass + 1 }  // 10/4 = 2.5 → 3 (away from zero)

	// RoundDivInt — small fractions.
	if math.RoundDivInt(1, 5) == 0 { pass = pass + 1 }
	if math.RoundDivInt(3, 5) == 1 { pass = pass + 1 }

	// RoundDivInt — invalid.
	if math.RoundDivInt(10, 0) == 0 { pass = pass + 1 }
	if math.RoundDivInt(-5, 3) == 0 { pass = pass + 1 }

	// Property: CeilDivInt always >= RoundDivInt for positive inputs.
	var c int = math.CeilDivInt(17, 5)
	var r int = math.RoundDivInt(17, 5)
	if c >= r { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
