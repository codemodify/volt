package main
import "log"
import "math"

// Positive test: math.IsPrime + math.NumDigits.

fun main() int {
	var pass int = 0

	// IsPrime — small primes.
	if math.IsPrime(2) { pass = pass + 1 }
	if math.IsPrime(3) { pass = pass + 1 }
	if math.IsPrime(5) { pass = pass + 1 }
	if math.IsPrime(7) { pass = pass + 1 }
	if math.IsPrime(11) { pass = pass + 1 }
	if math.IsPrime(13) { pass = pass + 1 }

	// IsPrime — composites.
	if !math.IsPrime(4) { pass = pass + 1 }
	if !math.IsPrime(9) { pass = pass + 1 }
	if !math.IsPrime(15) { pass = pass + 1 }
	if !math.IsPrime(25) { pass = pass + 1 }
	if !math.IsPrime(100) { pass = pass + 1 }

	// IsPrime — boundary / negative.
	if !math.IsPrime(0) { pass = pass + 1 }
	if !math.IsPrime(1) { pass = pass + 1 }
	if !math.IsPrime(-7) { pass = pass + 1 }

	// IsPrime — large prime + composite.
	if math.IsPrime(9973) { pass = pass + 1 }   // prime
	if !math.IsPrime(9999) { pass = pass + 1 }  // 3 × 3333

	// IsPrime — Mersenne-ish.
	if math.IsPrime(127) { pass = pass + 1 }    // 2^7 - 1
	if !math.IsPrime(2047) { pass = pass + 1 }  // 23 × 89 — famous Mersenne non-prime

	// NumDigits — basic.
	if math.NumDigits(0) == 1 { pass = pass + 1 }
	if math.NumDigits(1) == 1 { pass = pass + 1 }
	if math.NumDigits(9) == 1 { pass = pass + 1 }
	if math.NumDigits(10) == 2 { pass = pass + 1 }
	if math.NumDigits(99) == 2 { pass = pass + 1 }
	if math.NumDigits(100) == 3 { pass = pass + 1 }
	if math.NumDigits(1000) == 4 { pass = pass + 1 }
	if math.NumDigits(12345) == 5 { pass = pass + 1 }

	// NumDigits — negative (sign not counted).
	if math.NumDigits(-7) == 1 { pass = pass + 1 }
	if math.NumDigits(-100) == 3 { pass = pass + 1 }
	if math.NumDigits(-1234567890) == 10 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 29 { ret 42 }
	ret 0
}
