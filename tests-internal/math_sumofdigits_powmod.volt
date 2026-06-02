package main
import "log"
import "math"

// Positive test: math.SumOfDigits + math.PowMod.

fun main() int {
	var pass int = 0

	// SumOfDigits basic.
	if math.SumOfDigits(0) == 0 { pass = pass + 1 }
	if math.SumOfDigits(1) == 1 { pass = pass + 1 }
	if math.SumOfDigits(9) == 9 { pass = pass + 1 }
	if math.SumOfDigits(10) == 1 { pass = pass + 1 }
	if math.SumOfDigits(99) == 18 { pass = pass + 1 }
	if math.SumOfDigits(123) == 6 { pass = pass + 1 }
	if math.SumOfDigits(1000) == 1 { pass = pass + 1 }
	if math.SumOfDigits(9999) == 36 { pass = pass + 1 }

	// Negatives ignore sign.
	if math.SumOfDigits(-123) == 6 { pass = pass + 1 }
	if math.SumOfDigits(-9) == 9 { pass = pass + 1 }

	// Larger numbers.
	if math.SumOfDigits(12345) == 15 { pass = pass + 1 }
	if math.SumOfDigits(1000000) == 1 { pass = pass + 1 }

	// PowMod basic.
	if math.PowMod(2, 3, 5) == 3 { pass = pass + 1 }    // 8 mod 5 = 3
	if math.PowMod(2, 10, 100) == 24 { pass = pass + 1 } // 1024 mod 100
	if math.PowMod(3, 4, 11) == 4 { pass = pass + 1 }    // 81 mod 11 = 4

	// PowMod exp=0 → 1.
	if math.PowMod(5, 0, 7) == 1 { pass = pass + 1 }
	if math.PowMod(0, 0, 7) == 1 { pass = pass + 1 }    // convention 0^0 = 1

	// PowMod base=0, exp>0 → 0.
	if math.PowMod(0, 5, 7) == 0 { pass = pass + 1 }

	// PowMod m=1 → 0 (everything is 0 mod 1).
	if math.PowMod(7, 3, 1) == 0 { pass = pass + 1 }

	// PowMod large — Fermat's little theorem: 2^(p-1) mod p == 1 for prime p.
	if math.PowMod(2, 16, 17) == 1 { pass = pass + 1 }

	// PowMod negative exp → 0 (sentinel).
	if math.PowMod(2, -1, 5) == 0 { pass = pass + 1 }

	// PowMod m <= 0 → 0.
	if math.PowMod(2, 5, 0) == 0 { pass = pass + 1 }
	if math.PowMod(2, 5, -3) == 0 { pass = pass + 1 }

	// PowMod composability — (a*b) mod n == ((a mod n) * (b mod n)) mod n.
	// 13^5 mod 7: 13 mod 7 = 6; 6^5 = 7776; 7776 mod 7 = 6.
	if math.PowMod(13, 5, 7) == 6 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
