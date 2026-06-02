package main
import "log"
import "math"

// Positive test: math.PrevPrime + math.NthPrime.

fun main() int {
	var pass int = 0

	// PrevPrime — typical.
	if math.PrevPrime(10) == 7 { pass = pass + 1 }
	if math.PrevPrime(8) == 7 { pass = pass + 1 }
	if math.PrevPrime(7) == 5 { pass = pass + 1 }       // strictly less than n
	if math.PrevPrime(5) == 3 { pass = pass + 1 }
	if math.PrevPrime(3) == 2 { pass = pass + 1 }
	if math.PrevPrime(100) == 97 { pass = pass + 1 }
	if math.PrevPrime(1000) == 997 { pass = pass + 1 }

	// PrevPrime — domain edges (no smaller prime).
	if math.PrevPrime(2) == 0 { pass = pass + 1 }
	if math.PrevPrime(1) == 0 { pass = pass + 1 }
	if math.PrevPrime(0) == 0 { pass = pass + 1 }
	if math.PrevPrime(-5) == 0 { pass = pass + 1 }

	// NthPrime — first ten.
	if math.NthPrime(1) == 2 { pass = pass + 1 }
	if math.NthPrime(2) == 3 { pass = pass + 1 }
	if math.NthPrime(3) == 5 { pass = pass + 1 }
	if math.NthPrime(4) == 7 { pass = pass + 1 }
	if math.NthPrime(5) == 11 { pass = pass + 1 }
	if math.NthPrime(6) == 13 { pass = pass + 1 }
	if math.NthPrime(7) == 17 { pass = pass + 1 }
	if math.NthPrime(8) == 19 { pass = pass + 1 }
	if math.NthPrime(9) == 23 { pass = pass + 1 }
	if math.NthPrime(10) == 29 { pass = pass + 1 }

	// NthPrime — well-known higher values.
	if math.NthPrime(25) == 97 { pass = pass + 1 }      // 25th prime
	if math.NthPrime(100) == 541 { pass = pass + 1 }    // 100th prime
	if math.NthPrime(168) == 997 { pass = pass + 1 }    // 168th prime (largest < 1000)

	// NthPrime — domain edges.
	if math.NthPrime(0) == 0 { pass = pass + 1 }
	if math.NthPrime(-1) == 0 { pass = pass + 1 }

	// Inverse-ish: NextPrime(PrevPrime(n)) should be n if n itself is prime.
	if math.NextPrime(math.PrevPrime(11)) == 11 { pass = pass + 1 }
	if math.NextPrime(math.PrevPrime(23)) == 23 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 28 { ret 42 }
	ret 0
}
