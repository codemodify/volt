package main
import "log"
import "math"

// Positive test: math.Log2Floor + math.Log2Ceil.

fun main() int {
	var pass int = 0

	// Log2Floor — small values.
	if math.Log2Floor(1) == 0 { pass = pass + 1 }
	if math.Log2Floor(2) == 1 { pass = pass + 1 }
	if math.Log2Floor(3) == 1 { pass = pass + 1 }
	if math.Log2Floor(4) == 2 { pass = pass + 1 }
	if math.Log2Floor(7) == 2 { pass = pass + 1 }
	if math.Log2Floor(8) == 3 { pass = pass + 1 }
	if math.Log2Floor(15) == 3 { pass = pass + 1 }
	if math.Log2Floor(16) == 4 { pass = pass + 1 }
	if math.Log2Floor(31) == 4 { pass = pass + 1 }
	if math.Log2Floor(32) == 5 { pass = pass + 1 }

	// Log2Floor — larger.
	if math.Log2Floor(1023) == 9 { pass = pass + 1 }
	if math.Log2Floor(1024) == 10 { pass = pass + 1 }
	if math.Log2Floor(1048576) == 20 { pass = pass + 1 }

	// Log2Floor — domain.
	if math.Log2Floor(0) == -1 { pass = pass + 1 }
	if math.Log2Floor(-5) == -1 { pass = pass + 1 }

	// Log2Ceil — small values.
	if math.Log2Ceil(1) == 0 { pass = pass + 1 }
	if math.Log2Ceil(2) == 1 { pass = pass + 1 }
	if math.Log2Ceil(3) == 2 { pass = pass + 1 }
	if math.Log2Ceil(4) == 2 { pass = pass + 1 }
	if math.Log2Ceil(5) == 3 { pass = pass + 1 }
	if math.Log2Ceil(7) == 3 { pass = pass + 1 }
	if math.Log2Ceil(8) == 3 { pass = pass + 1 }
	if math.Log2Ceil(9) == 4 { pass = pass + 1 }
	if math.Log2Ceil(15) == 4 { pass = pass + 1 }
	if math.Log2Ceil(16) == 4 { pass = pass + 1 }
	if math.Log2Ceil(17) == 5 { pass = pass + 1 }

	// Log2Ceil — larger.
	if math.Log2Ceil(1024) == 10 { pass = pass + 1 }
	if math.Log2Ceil(1025) == 11 { pass = pass + 1 }

	// Log2Ceil — domain.
	if math.Log2Ceil(0) == -1 { pass = pass + 1 }
	if math.Log2Ceil(-3) == -1 { pass = pass + 1 }

	// Identity: Log2Floor(2^k) == k == Log2Ceil(2^k).
	if math.Log2Floor(64) == 6 { pass = pass + 1 }
	if math.Log2Ceil(64) == 6 { pass = pass + 1 }
	if math.Log2Floor(64) == math.Log2Ceil(64) { pass = pass + 1 }

	// Log2Ceil(n) >= Log2Floor(n) always.
	if math.Log2Ceil(100) >= math.Log2Floor(100) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 34 { ret 42 }
	ret 0
}
