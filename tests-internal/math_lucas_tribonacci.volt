package main
import "log"
import "math"

// Positive test: math.Lucas + math.Tribonacci.

fun main() int {
	var pass int = 0

	// Lucas — first ten.
	if math.Lucas(0) == 2 { pass = pass + 1 }
	if math.Lucas(1) == 1 { pass = pass + 1 }
	if math.Lucas(2) == 3 { pass = pass + 1 }
	if math.Lucas(3) == 4 { pass = pass + 1 }
	if math.Lucas(4) == 7 { pass = pass + 1 }
	if math.Lucas(5) == 11 { pass = pass + 1 }
	if math.Lucas(6) == 18 { pass = pass + 1 }
	if math.Lucas(7) == 29 { pass = pass + 1 }
	if math.Lucas(8) == 47 { pass = pass + 1 }
	if math.Lucas(9) == 76 { pass = pass + 1 }
	if math.Lucas(10) == 123 { pass = pass + 1 }

	// Lucas — bigger.
	if math.Lucas(20) == 15127 { pass = pass + 1 }
	if math.Lucas(30) == 1860498 { pass = pass + 1 }

	// Lucas — out of range.
	if math.Lucas(-1) == 0 { pass = pass + 1 }
	if math.Lucas(91) == 0 { pass = pass + 1 }

	// Lucas / Fibonacci identity: L(n) == F(n-1) + F(n+1) for n >= 1.
	if math.Lucas(5) == math.Fibonacci(4) + math.Fibonacci(6) { pass = pass + 1 }
	if math.Lucas(10) == math.Fibonacci(9) + math.Fibonacci(11) { pass = pass + 1 }

	// Tribonacci — first twelve (OEIS A000073).
	if math.Tribonacci(0) == 0 { pass = pass + 1 }
	if math.Tribonacci(1) == 1 { pass = pass + 1 }
	if math.Tribonacci(2) == 1 { pass = pass + 1 }
	if math.Tribonacci(3) == 2 { pass = pass + 1 }
	if math.Tribonacci(4) == 4 { pass = pass + 1 }
	if math.Tribonacci(5) == 7 { pass = pass + 1 }
	if math.Tribonacci(6) == 13 { pass = pass + 1 }
	if math.Tribonacci(7) == 24 { pass = pass + 1 }
	if math.Tribonacci(8) == 44 { pass = pass + 1 }
	if math.Tribonacci(9) == 81 { pass = pass + 1 }
	if math.Tribonacci(10) == 149 { pass = pass + 1 }
	if math.Tribonacci(11) == 274 { pass = pass + 1 }
	if math.Tribonacci(12) == 504 { pass = pass + 1 }

	// Tribonacci — bigger.
	if math.Tribonacci(20) == 35890 { pass = pass + 1 }
	if math.Tribonacci(30) == 15902591 { pass = pass + 1 }

	// Tribonacci — out of range.
	if math.Tribonacci(-1) == 0 { pass = pass + 1 }
	if math.Tribonacci(76) == 0 { pass = pass + 1 }

	// Recurrence sanity: T(15) == T(12) + T(13) + T(14).
	if math.Tribonacci(15) == math.Tribonacci(12) + math.Tribonacci(13) + math.Tribonacci(14) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 33 { ret 42 }
	ret 0
}
