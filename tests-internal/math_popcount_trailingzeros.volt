package main
import "log"
import "math"

// Positive test: math.PopCount + math.TrailingZeros.

fun main() int {
	var pass int = 0

	// PopCount — basic.
	if math.PopCount(0) == 0 { pass = pass + 1 }
	if math.PopCount(1) == 1 { pass = pass + 1 }
	if math.PopCount(2) == 1 { pass = pass + 1 }
	if math.PopCount(3) == 2 { pass = pass + 1 }
	if math.PopCount(4) == 1 { pass = pass + 1 }
	if math.PopCount(7) == 3 { pass = pass + 1 }
	if math.PopCount(8) == 1 { pass = pass + 1 }
	if math.PopCount(15) == 4 { pass = pass + 1 }
	if math.PopCount(255) == 8 { pass = pass + 1 }

	// PopCount — non-aligned values.
	if math.PopCount(12) == 2 { pass = pass + 1 }       // 1100
	if math.PopCount(170) == 4 { pass = pass + 1 }      // 10101010
	if math.PopCount(85) == 4 { pass = pass + 1 }       // 01010101

	// PopCount — bigger.
	if math.PopCount(65535) == 16 { pass = pass + 1 }
	if math.PopCount(65536) == 1 { pass = pass + 1 }
	if math.PopCount(1048576) == 1 { pass = pass + 1 }  // 2^20

	// PopCount — negatives use absolute value.
	if math.PopCount(-7) == 3 { pass = pass + 1 }
	if math.PopCount(-15) == 4 { pass = pass + 1 }

	// TrailingZeros — basic.
	if math.TrailingZeros(0) == 0 { pass = pass + 1 }
	if math.TrailingZeros(1) == 0 { pass = pass + 1 }
	if math.TrailingZeros(2) == 1 { pass = pass + 1 }
	if math.TrailingZeros(3) == 0 { pass = pass + 1 }
	if math.TrailingZeros(4) == 2 { pass = pass + 1 }
	if math.TrailingZeros(8) == 3 { pass = pass + 1 }
	if math.TrailingZeros(16) == 4 { pass = pass + 1 }
	if math.TrailingZeros(12) == 2 { pass = pass + 1 }  // 1100 → 2
	if math.TrailingZeros(24) == 3 { pass = pass + 1 }  // 11000 → 3
	if math.TrailingZeros(48) == 4 { pass = pass + 1 }  // 110000 → 4

	// TrailingZeros — large powers of 2.
	if math.TrailingZeros(1024) == 10 { pass = pass + 1 }
	if math.TrailingZeros(1048576) == 20 { pass = pass + 1 }

	// TrailingZeros — odd inputs.
	if math.TrailingZeros(7) == 0 { pass = pass + 1 }
	if math.TrailingZeros(255) == 0 { pass = pass + 1 }

	// TrailingZeros — negatives use absolute value.
	if math.TrailingZeros(-8) == 3 { pass = pass + 1 }
	if math.TrailingZeros(-12) == 2 { pass = pass + 1 }

	// Identity: PopCount(2^k) == 1.
	if math.PopCount(1024) == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 34 { ret 42 }
	ret 0
}
