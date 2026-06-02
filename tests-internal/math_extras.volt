package main
import "log"
import "math"

// Positive test: math.Sign / LcmInt / Pow2.

fun main() int {
	var pass int = 0

	// Sign.
	if math.Sign(-42) == -1 { pass = pass + 1 }
	if math.Sign(0) == 0 { pass = pass + 1 }
	if math.Sign(7) == 1 { pass = pass + 1 }
	if math.Sign(math.MaxInt) == 1 { pass = pass + 1 }
	if math.Sign(math.MinInt) == -1 { pass = pass + 1 }

	// LcmInt: standard cases.
	if math.LcmInt(4, 6) == 12 { pass = pass + 1 }
	if math.LcmInt(3, 5) == 15 { pass = pass + 1 }   // coprime
	if math.LcmInt(8, 8) == 8 { pass = pass + 1 }    // identical

	// LcmInt: sign-insensitive.
	if math.LcmInt(-4, 6) == 12 { pass = pass + 1 }
	if math.LcmInt(4, -6) == 12 { pass = pass + 1 }
	if math.LcmInt(-4, -6) == 12 { pass = pass + 1 }

	// LcmInt: zero operand.
	if math.LcmInt(0, 7) == 0 { pass = pass + 1 }
	if math.LcmInt(5, 0) == 0 { pass = pass + 1 }

	// Pow2.
	if math.Pow2(0) == 1 { pass = pass + 1 }
	if math.Pow2(1) == 2 { pass = pass + 1 }
	if math.Pow2(10) == 1024 { pass = pass + 1 }
	if math.Pow2(62) == 4611686018427387904 { pass = pass + 1 }

	// Pow2: out-of-range → 0.
	if math.Pow2(-1) == 0 { pass = pass + 1 }
	if math.Pow2(63) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
