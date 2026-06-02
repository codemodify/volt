package main
import "log"
import "math"

// Positive test: math.Fibonacci + math.Catalan.

fun main() int {
	var pass int = 0

	// Fibonacci — first dozen.
	if math.Fibonacci(0) == 0 { pass = pass + 1 }
	if math.Fibonacci(1) == 1 { pass = pass + 1 }
	if math.Fibonacci(2) == 1 { pass = pass + 1 }
	if math.Fibonacci(3) == 2 { pass = pass + 1 }
	if math.Fibonacci(4) == 3 { pass = pass + 1 }
	if math.Fibonacci(5) == 5 { pass = pass + 1 }
	if math.Fibonacci(6) == 8 { pass = pass + 1 }
	if math.Fibonacci(7) == 13 { pass = pass + 1 }
	if math.Fibonacci(10) == 55 { pass = pass + 1 }
	if math.Fibonacci(20) == 6765 { pass = pass + 1 }

	// Fibonacci — near-overflow.
	if math.Fibonacci(50) == 12586269025 { pass = pass + 1 }
	if math.Fibonacci(92) == 7540113804746346429 { pass = pass + 1 }

	// Fibonacci — out of range.
	if math.Fibonacci(-1) == 0 { pass = pass + 1 }
	if math.Fibonacci(93) == 0 { pass = pass + 1 }
	if math.Fibonacci(100) == 0 { pass = pass + 1 }

	// Catalan — first ten.
	if math.Catalan(0) == 1 { pass = pass + 1 }
	if math.Catalan(1) == 1 { pass = pass + 1 }
	if math.Catalan(2) == 2 { pass = pass + 1 }
	if math.Catalan(3) == 5 { pass = pass + 1 }
	if math.Catalan(4) == 14 { pass = pass + 1 }
	if math.Catalan(5) == 42 { pass = pass + 1 }
	if math.Catalan(6) == 132 { pass = pass + 1 }
	if math.Catalan(7) == 429 { pass = pass + 1 }
	if math.Catalan(8) == 1430 { pass = pass + 1 }
	if math.Catalan(9) == 4862 { pass = pass + 1 }
	if math.Catalan(10) == 16796 { pass = pass + 1 }

	// Catalan — out of range.
	if math.Catalan(-1) == 0 { pass = pass + 1 }
	if math.Catalan(34) == 0 { pass = pass + 1 }

	// Fibonacci recurrence sanity check: F(15) == F(13) + F(14).
	if math.Fibonacci(15) == math.Fibonacci(13) + math.Fibonacci(14) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 29 { ret 42 }
	ret 0
}
