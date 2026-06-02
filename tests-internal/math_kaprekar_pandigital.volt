package main
import "log"
import "math"

// Positive test: math.IsKaprekar + math.IsPandigital.

fun main() int {
	var pass int = 0

	// IsKaprekar — classical Kaprekar numbers.
	if math.IsKaprekar(1) { pass = pass + 1 }       // trivially
	if math.IsKaprekar(9) { pass = pass + 1 }       // 9²=81 → 8+1=9
	if math.IsKaprekar(45) { pass = pass + 1 }      // 45²=2025 → 20+25=45
	if math.IsKaprekar(55) { pass = pass + 1 }      // 55²=3025 → 30+25=55
	if math.IsKaprekar(99) { pass = pass + 1 }      // 99²=9801 → 98+01=99
	if math.IsKaprekar(297) { pass = pass + 1 }     // 297²=88209 → 88+209=297
	if math.IsKaprekar(703) { pass = pass + 1 }     // 703²=494209 → 494+209=703
	if math.IsKaprekar(999) { pass = pass + 1 }     // 999²=998001 → 998+001=999

	// IsKaprekar — non-Kaprekar.
	if !math.IsKaprekar(2) { pass = pass + 1 }
	if !math.IsKaprekar(3) { pass = pass + 1 }
	if !math.IsKaprekar(10) { pass = pass + 1 }
	if !math.IsKaprekar(100) { pass = pass + 1 }
	if !math.IsKaprekar(456) { pass = pass + 1 }

	// IsKaprekar — domain edges.
	if !math.IsKaprekar(0) { pass = pass + 1 }
	if !math.IsKaprekar(-9) { pass = pass + 1 }

	// IsPandigital — true examples (every digit 0..9 present).
	if math.IsPandigital(1023456789) { pass = pass + 1 }
	if math.IsPandigital(1234567890) { pass = pass + 1 }
	if math.IsPandigital(9876543210) { pass = pass + 1 }
	if math.IsPandigital(12345678900) { pass = pass + 1 }   // 11-digit with all 10 distinct

	// IsPandigital — missing digits.
	if !math.IsPandigital(123456789) { pass = pass + 1 }    // no 0
	if !math.IsPandigital(12345) { pass = pass + 1 }
	if !math.IsPandigital(0) { pass = pass + 1 }            // only 0
	if !math.IsPandigital(1) { pass = pass + 1 }

	// IsPandigital — negative rejected.
	if !math.IsPandigital(-1023456789) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
