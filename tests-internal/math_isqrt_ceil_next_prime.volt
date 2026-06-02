package main
import "log"
import "math"

// Positive test: math.IsqrtCeil + math.NextPrime.

fun main() int {
	var pass int = 0

	// IsqrtCeil exact squares.
	if math.IsqrtCeil(0) == 0 { pass = pass + 1 }
	if math.IsqrtCeil(1) == 1 { pass = pass + 1 }
	if math.IsqrtCeil(4) == 2 { pass = pass + 1 }
	if math.IsqrtCeil(9) == 3 { pass = pass + 1 }
	if math.IsqrtCeil(100) == 10 { pass = pass + 1 }

	// IsqrtCeil non-square — ceiling.
	if math.IsqrtCeil(2) == 2 { pass = pass + 1 }     // sqrt(2)~1.41 → 2
	if math.IsqrtCeil(3) == 2 { pass = pass + 1 }     // sqrt(3)~1.73 → 2
	if math.IsqrtCeil(5) == 3 { pass = pass + 1 }     // sqrt(5)~2.23 → 3
	if math.IsqrtCeil(10) == 4 { pass = pass + 1 }    // sqrt(10)~3.16 → 4
	if math.IsqrtCeil(99) == 10 { pass = pass + 1 }   // sqrt(99)~9.95 → 10
	if math.IsqrtCeil(101) == 11 { pass = pass + 1 }  // sqrt(101)~10.04 → 11

	// Negatives → 0.
	if math.IsqrtCeil(-1) == 0 { pass = pass + 1 }
	if math.IsqrtCeil(-100) == 0 { pass = pass + 1 }

	// NextPrime — basic.
	if math.NextPrime(0) == 2 { pass = pass + 1 }
	if math.NextPrime(1) == 2 { pass = pass + 1 }
	if math.NextPrime(2) == 3 { pass = pass + 1 }
	if math.NextPrime(3) == 5 { pass = pass + 1 }
	if math.NextPrime(5) == 7 { pass = pass + 1 }
	if math.NextPrime(7) == 11 { pass = pass + 1 }
	if math.NextPrime(13) == 17 { pass = pass + 1 }

	// Composite input — skips ahead to next prime.
	if math.NextPrime(8) == 11 { pass = pass + 1 }
	if math.NextPrime(14) == 17 { pass = pass + 1 }
	if math.NextPrime(100) == 101 { pass = pass + 1 }

	// Negatives → 2.
	if math.NextPrime(-5) == 2 { pass = pass + 1 }
	if math.NextPrime(-1000) == 2 { pass = pass + 1 }

	// Larger prime gap — 23 → 29.
	if math.NextPrime(23) == 29 { pass = pass + 1 }

	// Just past 100.
	if math.NextPrime(110) == 113 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
