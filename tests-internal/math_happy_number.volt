package main
import "log"
import "math"

// Positive test: math.SumSquaresDigits + math.IsHappyNumber.

fun main() int {
	var pass int = 0

	// SumSquaresDigits basic.
	if math.SumSquaresDigits(0) == 0 { pass = pass + 1 }
	if math.SumSquaresDigits(1) == 1 { pass = pass + 1 }
	if math.SumSquaresDigits(9) == 81 { pass = pass + 1 }
	if math.SumSquaresDigits(10) == 1 { pass = pass + 1 }     // 1+0
	if math.SumSquaresDigits(23) == 13 { pass = pass + 1 }    // 4+9
	if math.SumSquaresDigits(99) == 162 { pass = pass + 1 }   // 81+81
	if math.SumSquaresDigits(123) == 14 { pass = pass + 1 }   // 1+4+9
	if math.SumSquaresDigits(1234) == 30 { pass = pass + 1 }  // 1+4+9+16

	// SumSquaresDigits negative — ignores sign.
	if math.SumSquaresDigits(-23) == 13 { pass = pass + 1 }

	// IsHappyNumber — known happy numbers (OEIS A007770).
	if math.IsHappyNumber(1) { pass = pass + 1 }
	if math.IsHappyNumber(7) { pass = pass + 1 }
	if math.IsHappyNumber(10) { pass = pass + 1 }
	if math.IsHappyNumber(13) { pass = pass + 1 }
	if math.IsHappyNumber(19) { pass = pass + 1 }
	if math.IsHappyNumber(23) { pass = pass + 1 }
	if math.IsHappyNumber(28) { pass = pass + 1 }
	if math.IsHappyNumber(31) { pass = pass + 1 }
	if math.IsHappyNumber(32) { pass = pass + 1 }
	if math.IsHappyNumber(44) { pass = pass + 1 }
	if math.IsHappyNumber(100) { pass = pass + 1 }

	// IsHappyNumber — known unhappy numbers (cycle).
	if !math.IsHappyNumber(2) { pass = pass + 1 }
	if !math.IsHappyNumber(3) { pass = pass + 1 }
	if !math.IsHappyNumber(4) { pass = pass + 1 }
	if !math.IsHappyNumber(5) { pass = pass + 1 }
	if !math.IsHappyNumber(6) { pass = pass + 1 }
	if !math.IsHappyNumber(8) { pass = pass + 1 }
	if !math.IsHappyNumber(9) { pass = pass + 1 }
	if !math.IsHappyNumber(11) { pass = pass + 1 }
	if !math.IsHappyNumber(12) { pass = pass + 1 }

	// IsHappyNumber edge.
	if !math.IsHappyNumber(0) { pass = pass + 1 }
	if !math.IsHappyNumber(-7) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 31 { ret 42 }
	ret 0
}
