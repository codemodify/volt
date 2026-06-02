package main
import "log"
import "math"

// Positive test: math.SumDivisors + math.IsPerfect.

fun main() int {
	var pass int = 0

	// SumDivisors small.
	if math.SumDivisors(1) == 1 { pass = pass + 1 }       // 1
	if math.SumDivisors(2) == 3 { pass = pass + 1 }       // 1+2
	if math.SumDivisors(3) == 4 { pass = pass + 1 }       // 1+3
	if math.SumDivisors(4) == 7 { pass = pass + 1 }       // 1+2+4
	if math.SumDivisors(6) == 12 { pass = pass + 1 }      // 1+2+3+6
	if math.SumDivisors(10) == 18 { pass = pass + 1 }     // 1+2+5+10
	if math.SumDivisors(12) == 28 { pass = pass + 1 }     // 1+2+3+4+6+12

	// SumDivisors perfect squares — the sqrt isn't double-counted.
	if math.SumDivisors(9) == 13 { pass = pass + 1 }      // 1+3+9
	if math.SumDivisors(16) == 31 { pass = pass + 1 }     // 1+2+4+8+16
	if math.SumDivisors(25) == 31 { pass = pass + 1 }     // 1+5+25

	// SumDivisors prime.
	if math.SumDivisors(7) == 8 { pass = pass + 1 }       // 1+7
	if math.SumDivisors(13) == 14 { pass = pass + 1 }     // 1+13

	// SumDivisors edge.
	if math.SumDivisors(0) == 0 { pass = pass + 1 }
	if math.SumDivisors(-12) == 0 { pass = pass + 1 }

	// IsPerfect known perfect numbers.
	if math.IsPerfect(6) { pass = pass + 1 }              // 1+2+3=6
	if math.IsPerfect(28) { pass = pass + 1 }             // 1+2+4+7+14=28
	if math.IsPerfect(496) { pass = pass + 1 }
	if math.IsPerfect(8128) { pass = pass + 1 }

	// IsPerfect deficient (sum < n).
	if !math.IsPerfect(2) { pass = pass + 1 }
	if !math.IsPerfect(5) { pass = pass + 1 }
	if !math.IsPerfect(7) { pass = pass + 1 }
	if !math.IsPerfect(10) { pass = pass + 1 }

	// IsPerfect abundant (sum > n).
	if !math.IsPerfect(12) { pass = pass + 1 }            // proper sum = 16
	if !math.IsPerfect(24) { pass = pass + 1 }

	// IsPerfect edge.
	if !math.IsPerfect(0) { pass = pass + 1 }
	if !math.IsPerfect(1) { pass = pass + 1 }
	if !math.IsPerfect(-6) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
