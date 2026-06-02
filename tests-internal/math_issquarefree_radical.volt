package main
import "log"
import "math"

// Positive test: math.IsSquarefree + math.RadicalInt.

fun main() int {
	var pass int = 0

	// IsSquarefree — small squarefree numbers.
	if math.IsSquarefree(1) { pass = pass + 1 }
	if math.IsSquarefree(2) { pass = pass + 1 }
	if math.IsSquarefree(3) { pass = pass + 1 }
	if math.IsSquarefree(5) { pass = pass + 1 }
	if math.IsSquarefree(6) { pass = pass + 1 }
	if math.IsSquarefree(7) { pass = pass + 1 }
	if math.IsSquarefree(10) { pass = pass + 1 }
	if math.IsSquarefree(15) { pass = pass + 1 }
	if math.IsSquarefree(30) { pass = pass + 1 }     // 2*3*5

	// IsSquarefree — not squarefree (has p^2 factor).
	if !math.IsSquarefree(4) { pass = pass + 1 }
	if !math.IsSquarefree(8) { pass = pass + 1 }
	if !math.IsSquarefree(9) { pass = pass + 1 }
	if !math.IsSquarefree(12) { pass = pass + 1 }    // 4*3
	if !math.IsSquarefree(18) { pass = pass + 1 }
	if !math.IsSquarefree(25) { pass = pass + 1 }
	if !math.IsSquarefree(50) { pass = pass + 1 }
	if !math.IsSquarefree(100) { pass = pass + 1 }

	// IsSquarefree — domain.
	if !math.IsSquarefree(0) { pass = pass + 1 }
	if !math.IsSquarefree(-6) { pass = pass + 1 }

	// RadicalInt — basic.
	if math.RadicalInt(1) == 1 { pass = pass + 1 }
	if math.RadicalInt(2) == 2 { pass = pass + 1 }
	if math.RadicalInt(6) == 6 { pass = pass + 1 }   // squarefree → identity
	if math.RadicalInt(12) == 6 { pass = pass + 1 }  // 2*3
	if math.RadicalInt(72) == 6 { pass = pass + 1 }  // 2*3
	if math.RadicalInt(30) == 30 { pass = pass + 1 } // squarefree → identity
	if math.RadicalInt(100) == 10 { pass = pass + 1 } // 2*5

	// RadicalInt — prime returns itself.
	if math.RadicalInt(13) == 13 { pass = pass + 1 }
	if math.RadicalInt(97) == 97 { pass = pass + 1 }

	// RadicalInt — prime power.
	if math.RadicalInt(8) == 2 { pass = pass + 1 }
	if math.RadicalInt(27) == 3 { pass = pass + 1 }

	// RadicalInt — domain.
	if math.RadicalInt(0) == 0 { pass = pass + 1 }
	if math.RadicalInt(-12) == 0 { pass = pass + 1 }

	// Identity: IsSquarefree(n) ↔ RadicalInt(n) == n.
	if math.IsSquarefree(15) {
		if math.RadicalInt(15) == 15 { pass = pass + 1 }
	}
	if !math.IsSquarefree(12) {
		if math.RadicalInt(12) != 12 { pass = pass + 1 }
	}

	log.Println("pass=%d", pass)
	if pass == 34 { ret 42 }
	ret 0
}
