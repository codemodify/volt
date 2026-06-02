package main
import "log"
import "math"

// Positive test: math.SumDigits + math.ReverseDigits.

fun main() int {
	var pass int = 0

	// SumDigits — basic.
	if math.SumDigits(0) == 0 { pass = pass + 1 }
	if math.SumDigits(7) == 7 { pass = pass + 1 }
	if math.SumDigits(10) == 1 { pass = pass + 1 }
	if math.SumDigits(123) == 6 { pass = pass + 1 }
	if math.SumDigits(99999) == 45 { pass = pass + 1 }
	if math.SumDigits(1000000) == 1 { pass = pass + 1 }

	// SumDigits — negative (sign dropped).
	if math.SumDigits(-1) == 1 { pass = pass + 1 }
	if math.SumDigits(-123) == 6 { pass = pass + 1 }

	// ReverseDigits — basic.
	if math.ReverseDigits(0) == 0 { pass = pass + 1 }
	if math.ReverseDigits(7) == 7 { pass = pass + 1 }
	if math.ReverseDigits(12) == 21 { pass = pass + 1 }
	if math.ReverseDigits(123) == 321 { pass = pass + 1 }
	if math.ReverseDigits(12345) == 54321 { pass = pass + 1 }

	// ReverseDigits — trailing zeros drop.
	if math.ReverseDigits(100) == 1 { pass = pass + 1 }
	if math.ReverseDigits(120) == 21 { pass = pass + 1 }
	if math.ReverseDigits(1000) == 1 { pass = pass + 1 }

	// ReverseDigits — palindromic preserved.
	if math.ReverseDigits(121) == 121 { pass = pass + 1 }
	if math.ReverseDigits(1221) == 1221 { pass = pass + 1 }

	// ReverseDigits — negative (sign preserved).
	if math.ReverseDigits(-123) == -321 { pass = pass + 1 }
	if math.ReverseDigits(-100) == -1 { pass = pass + 1 }

	// Combined: ReverseDigits roundtrip on a palindrome.
	if math.ReverseDigits(math.ReverseDigits(54321)) == 54321 { pass = pass + 1 }

	// Combined: SumDigits is invariant under digit reversal.
	if math.SumDigits(12345) == math.SumDigits(math.ReverseDigits(12345)) { pass = pass + 1 }

	// Harshad number check: 18 is divisible by SumDigits(18)=9.
	if math.IsMultipleOf(18, math.SumDigits(18)) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
