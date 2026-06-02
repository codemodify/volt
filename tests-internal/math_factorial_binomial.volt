package main
import "log"
import "math"

// Positive test: math.Factorial + math.Binomial.

fun main() int {
	var pass int = 0

	// Factorial — small values.
	if math.Factorial(0) == 1 { pass = pass + 1 }
	if math.Factorial(1) == 1 { pass = pass + 1 }
	if math.Factorial(2) == 2 { pass = pass + 1 }
	if math.Factorial(3) == 6 { pass = pass + 1 }
	if math.Factorial(4) == 24 { pass = pass + 1 }
	if math.Factorial(5) == 120 { pass = pass + 1 }
	if math.Factorial(10) == 3628800 { pass = pass + 1 }

	// 20! = 2432902008176640000 (largest that fits int64).
	if math.Factorial(20) == 2432902008176640000 { pass = pass + 1 }

	// Out-of-range.
	if math.Factorial(-1) == 0 { pass = pass + 1 }
	if math.Factorial(21) == 0 { pass = pass + 1 }

	// Binomial — Pascal's triangle.
	if math.Binomial(0, 0) == 1 { pass = pass + 1 }
	if math.Binomial(1, 0) == 1 { pass = pass + 1 }
	if math.Binomial(1, 1) == 1 { pass = pass + 1 }
	if math.Binomial(2, 1) == 2 { pass = pass + 1 }
	if math.Binomial(4, 2) == 6 { pass = pass + 1 }
	if math.Binomial(5, 2) == 10 { pass = pass + 1 }
	if math.Binomial(6, 3) == 20 { pass = pass + 1 }
	if math.Binomial(10, 5) == 252 { pass = pass + 1 }

	// Symmetry: C(n, k) == C(n, n-k).
	if math.Binomial(20, 7) == math.Binomial(20, 13) { pass = pass + 1 }

	// Edge: k > n.
	if math.Binomial(5, 6) == 0 { pass = pass + 1 }

	// Edge: negatives.
	if math.Binomial(-1, 2) == 0 { pass = pass + 1 }
	if math.Binomial(5, -1) == 0 { pass = pass + 1 }

	// k = n.
	if math.Binomial(7, 7) == 1 { pass = pass + 1 }

	// k = 0.
	if math.Binomial(100, 0) == 1 { pass = pass + 1 }

	// Large but fits — C(30, 15) = 155117520.
	if math.Binomial(30, 15) == 155117520 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
