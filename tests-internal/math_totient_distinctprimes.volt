package main
import "log"
import "math"

// Positive test: math.DistinctPrimeFactors + math.Totient.

fun main() int {
	var pass int = 0

	// DistinctPrimeFactors — basic.
	var d12 []int = math.DistinctPrimeFactors(12)   // primes 2, 3
	if len(d12) == 2 { pass = pass + 1 }
	if d12[0] == 2 { pass = pass + 1 }
	if d12[1] == 3 { pass = pass + 1 }

	var d100 []int = math.DistinctPrimeFactors(100)   // 2^2 * 5^2 → {2, 5}
	if len(d100) == 2 { pass = pass + 1 }
	if d100[0] == 2 { pass = pass + 1 }
	if d100[1] == 5 { pass = pass + 1 }

	// DistinctPrimeFactors — prime stays single.
	var d13 []int = math.DistinctPrimeFactors(13)
	if len(d13) == 1 { pass = pass + 1 }
	if d13[0] == 13 { pass = pass + 1 }

	// DistinctPrimeFactors — prime power.
	var d8 []int = math.DistinctPrimeFactors(8)
	if len(d8) == 1 { pass = pass + 1 }
	if d8[0] == 2 { pass = pass + 1 }

	// DistinctPrimeFactors — n<2 → empty.
	var d1 []int = math.DistinctPrimeFactors(1)
	if len(d1) == 0 { pass = pass + 1 }
	var d0 []int = math.DistinctPrimeFactors(0)
	if len(d0) == 0 { pass = pass + 1 }

	// DistinctPrimeFactors — semiprime.
	var d30 []int = math.DistinctPrimeFactors(30)   // 2*3*5
	if len(d30) == 3 { pass = pass + 1 }
	if d30[0] == 2 { pass = pass + 1 }
	if d30[2] == 5 { pass = pass + 1 }

	// Totient — small cases.
	if math.Totient(1) == 1 { pass = pass + 1 }
	if math.Totient(2) == 1 { pass = pass + 1 }
	if math.Totient(3) == 2 { pass = pass + 1 }
	if math.Totient(4) == 2 { pass = pass + 1 }
	if math.Totient(5) == 4 { pass = pass + 1 }
	if math.Totient(6) == 2 { pass = pass + 1 }
	if math.Totient(9) == 6 { pass = pass + 1 }
	if math.Totient(10) == 4 { pass = pass + 1 }
	if math.Totient(12) == 4 { pass = pass + 1 }
	if math.Totient(36) == 12 { pass = pass + 1 }

	// Totient — primes p give p-1.
	if math.Totient(7) == 6 { pass = pass + 1 }
	if math.Totient(13) == 12 { pass = pass + 1 }
	if math.Totient(97) == 96 { pass = pass + 1 }

	// Totient — domain.
	if math.Totient(0) == 0 { pass = pass + 1 }
	if math.Totient(-5) == 0 { pass = pass + 1 }

	// Totient(p^k) = p^(k-1)*(p-1).
	if math.Totient(8) == 4 { pass = pass + 1 }     // 2^3 → 2^2 * 1 = 4
	if math.Totient(27) == 18 { pass = pass + 1 }   // 3^3 → 9 * 2 = 18

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
