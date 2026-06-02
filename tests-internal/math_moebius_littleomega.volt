package main
import "log"
import "math"

// Positive test: math.MoebiusInt + math.LittleOmega.

fun main() int {
	var pass int = 0

	// MoebiusInt — μ(1) = 1.
	if math.MoebiusInt(1) == 1 { pass = pass + 1 }

	// MoebiusInt — primes are squarefree with 1 factor → -1.
	if math.MoebiusInt(2) == -1 { pass = pass + 1 }
	if math.MoebiusInt(3) == -1 { pass = pass + 1 }
	if math.MoebiusInt(5) == -1 { pass = pass + 1 }
	if math.MoebiusInt(7) == -1 { pass = pass + 1 }

	// MoebiusInt — semiprimes p*q → +1.
	if math.MoebiusInt(6) == 1 { pass = pass + 1 }     // 2*3
	if math.MoebiusInt(10) == 1 { pass = pass + 1 }    // 2*5
	if math.MoebiusInt(14) == 1 { pass = pass + 1 }    // 2*7
	if math.MoebiusInt(15) == 1 { pass = pass + 1 }    // 3*5

	// MoebiusInt — triple-prime squarefree → -1.
	if math.MoebiusInt(30) == -1 { pass = pass + 1 }   // 2*3*5
	if math.MoebiusInt(42) == -1 { pass = pass + 1 }   // 2*3*7

	// MoebiusInt — has square factor → 0.
	if math.MoebiusInt(4) == 0 { pass = pass + 1 }
	if math.MoebiusInt(8) == 0 { pass = pass + 1 }
	if math.MoebiusInt(12) == 0 { pass = pass + 1 }
	if math.MoebiusInt(18) == 0 { pass = pass + 1 }
	if math.MoebiusInt(25) == 0 { pass = pass + 1 }
	if math.MoebiusInt(50) == 0 { pass = pass + 1 }
	if math.MoebiusInt(100) == 0 { pass = pass + 1 }

	// MoebiusInt — domain.
	if math.MoebiusInt(0) == 0 { pass = pass + 1 }
	if math.MoebiusInt(-5) == 0 { pass = pass + 1 }

	// LittleOmega — basic.
	if math.LittleOmega(1) == 0 { pass = pass + 1 }
	if math.LittleOmega(2) == 1 { pass = pass + 1 }
	if math.LittleOmega(4) == 1 { pass = pass + 1 }    // 2^2: 1 distinct prime
	if math.LittleOmega(6) == 2 { pass = pass + 1 }    // 2, 3
	if math.LittleOmega(12) == 2 { pass = pass + 1 }   // 2^2 * 3 → 2 distinct
	if math.LittleOmega(30) == 3 { pass = pass + 1 }   // 2*3*5
	if math.LittleOmega(60) == 3 { pass = pass + 1 }   // 2^2*3*5 → 3 distinct
	if math.LittleOmega(2310) == 5 { pass = pass + 1 } // 2*3*5*7*11

	// LittleOmega — primes always have 1.
	if math.LittleOmega(97) == 1 { pass = pass + 1 }

	// LittleOmega — domain.
	if math.LittleOmega(0) == 0 { pass = pass + 1 }
	if math.LittleOmega(-12) == 0 { pass = pass + 1 }

	// Cross-check: when n is squarefree, |MoebiusInt(n)| == 1 and matches (-1)^LittleOmega.
	// For 30 (squarefree, ω=3): μ = -1, (-1)^3 = -1. Match.
	if math.MoebiusInt(30) == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
