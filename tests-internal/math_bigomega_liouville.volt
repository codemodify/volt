package main
import "log"
import "math"

// Positive test: math.BigOmega + math.LiouvilleInt.

fun main() int {
	var pass int = 0

	// BigOmega — basic.
	if math.BigOmega(1) == 0 { pass = pass + 1 }
	if math.BigOmega(2) == 1 { pass = pass + 1 }
	if math.BigOmega(3) == 1 { pass = pass + 1 }
	if math.BigOmega(4) == 2 { pass = pass + 1 }    // 2, 2
	if math.BigOmega(6) == 2 { pass = pass + 1 }    // 2, 3
	if math.BigOmega(8) == 3 { pass = pass + 1 }    // 2, 2, 2
	if math.BigOmega(12) == 3 { pass = pass + 1 }   // 2, 2, 3
	if math.BigOmega(30) == 3 { pass = pass + 1 }   // 2, 3, 5
	if math.BigOmega(60) == 4 { pass = pass + 1 }   // 2, 2, 3, 5
	if math.BigOmega(64) == 6 { pass = pass + 1 }   // 2^6
	if math.BigOmega(100) == 4 { pass = pass + 1 }  // 2,2,5,5

	// BigOmega — primes always 1.
	if math.BigOmega(97) == 1 { pass = pass + 1 }
	if math.BigOmega(101) == 1 { pass = pass + 1 }

	// BigOmega — domain.
	if math.BigOmega(0) == 0 { pass = pass + 1 }
	if math.BigOmega(-5) == 0 { pass = pass + 1 }

	// LiouvilleInt — λ(1) = 1 (Ω=0, even).
	if math.LiouvilleInt(1) == 1 { pass = pass + 1 }

	// LiouvilleInt — primes have Ω=1 (odd) → -1.
	if math.LiouvilleInt(2) == -1 { pass = pass + 1 }
	if math.LiouvilleInt(3) == -1 { pass = pass + 1 }
	if math.LiouvilleInt(5) == -1 { pass = pass + 1 }

	// LiouvilleInt — Ω=2 (even) → +1.
	if math.LiouvilleInt(4) == 1 { pass = pass + 1 }    // 2,2
	if math.LiouvilleInt(6) == 1 { pass = pass + 1 }    // 2,3
	if math.LiouvilleInt(9) == 1 { pass = pass + 1 }    // 3,3
	if math.LiouvilleInt(10) == 1 { pass = pass + 1 }   // 2,5

	// LiouvilleInt — Ω=3 (odd) → -1.
	if math.LiouvilleInt(8) == -1 { pass = pass + 1 }
	if math.LiouvilleInt(12) == -1 { pass = pass + 1 }
	if math.LiouvilleInt(30) == -1 { pass = pass + 1 }

	// LiouvilleInt — Ω=4 (even) → +1.
	if math.LiouvilleInt(60) == 1 { pass = pass + 1 }
	if math.LiouvilleInt(16) == 1 { pass = pass + 1 }   // 2,2,2,2

	// LiouvilleInt — domain.
	if math.LiouvilleInt(0) == 0 { pass = pass + 1 }
	if math.LiouvilleInt(-5) == 0 { pass = pass + 1 }

	// Identity: BigOmega(n) >= LittleOmega(n).
	if math.BigOmega(60) >= math.LittleOmega(60) { pass = pass + 1 }

	// Squarefree n: BigOmega == LittleOmega.
	if math.BigOmega(30) == math.LittleOmega(30) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 32 { ret 42 }
	ret 0
}
