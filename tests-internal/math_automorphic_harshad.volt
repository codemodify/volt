package main
import "log"
import "math"

// Positive test: math.IsAutomorphic + math.IsHarshad.

fun main() int {
	var pass int = 0

	// IsAutomorphic — single-digit base cases (0, 1, 5, 6).
	if math.IsAutomorphic(0) { pass = pass + 1 }
	if math.IsAutomorphic(1) { pass = pass + 1 }
	if math.IsAutomorphic(5) { pass = pass + 1 }
	if math.IsAutomorphic(6) { pass = pass + 1 }

	// IsAutomorphic — non-automorphic single-digits.
	if !math.IsAutomorphic(2) { pass = pass + 1 }
	if !math.IsAutomorphic(7) { pass = pass + 1 }
	if !math.IsAutomorphic(9) { pass = pass + 1 }

	// IsAutomorphic — two-digit (25 → 625, 76 → 5776).
	if math.IsAutomorphic(25) { pass = pass + 1 }
	if math.IsAutomorphic(76) { pass = pass + 1 }

	// IsAutomorphic — non-automorphic two-digit.
	if !math.IsAutomorphic(10) { pass = pass + 1 }
	if !math.IsAutomorphic(50) { pass = pass + 1 }

	// IsAutomorphic — three-digit (376 → 141376, 625 → 390625).
	if math.IsAutomorphic(376) { pass = pass + 1 }
	if math.IsAutomorphic(625) { pass = pass + 1 }

	// IsAutomorphic — negatives rejected.
	if !math.IsAutomorphic(-5) { pass = pass + 1 }
	if !math.IsAutomorphic(-25) { pass = pass + 1 }

	// IsHarshad — first few positives (every 1..9 is trivially Harshad).
	if math.IsHarshad(1) { pass = pass + 1 }
	if math.IsHarshad(9) { pass = pass + 1 }
	if math.IsHarshad(10) { pass = pass + 1 }       // 10/1=10
	if math.IsHarshad(12) { pass = pass + 1 }       // 12/3=4
	if math.IsHarshad(18) { pass = pass + 1 }       // 18/9=2
	if math.IsHarshad(21) { pass = pass + 1 }       // 21/3=7
	if math.IsHarshad(24) { pass = pass + 1 }       // 24/6=4

	// IsHarshad — non-Harshad.
	if !math.IsHarshad(11) { pass = pass + 1 }      // sum=2, 11%2=1
	if !math.IsHarshad(13) { pass = pass + 1 }      // sum=4, 13%4=1
	if !math.IsHarshad(19) { pass = pass + 1 }      // sum=10, 19%10=9

	// IsHarshad — 0 and negatives rejected (domain n > 0).
	if !math.IsHarshad(0) { pass = pass + 1 }
	if !math.IsHarshad(-12) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
