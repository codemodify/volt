package main
import "log"
import "math"

// Positive test: math.IsAbundant + math.IsDeficient.

fun main() int {
	var pass int = 0

	// Abundant numbers — known small examples.
	if math.IsAbundant(12) { pass = pass + 1 }
	if math.IsAbundant(18) { pass = pass + 1 }
	if math.IsAbundant(20) { pass = pass + 1 }
	if math.IsAbundant(24) { pass = pass + 1 }
	if math.IsAbundant(30) { pass = pass + 1 }
	if math.IsAbundant(36) { pass = pass + 1 }

	// Perfect numbers — NOT abundant (proper sum == n, not >).
	if !math.IsAbundant(6) { pass = pass + 1 }
	if !math.IsAbundant(28) { pass = pass + 1 }

	// Deficient numbers — NOT abundant.
	if !math.IsAbundant(7) { pass = pass + 1 }
	if !math.IsAbundant(10) { pass = pass + 1 }
	if !math.IsAbundant(11) { pass = pass + 1 }

	// Edge — out of domain.
	if !math.IsAbundant(0) { pass = pass + 1 }
	if !math.IsAbundant(1) { pass = pass + 1 }
	if !math.IsAbundant(-12) { pass = pass + 1 }

	// Deficient numbers — primes are always deficient (proper sum = 1 < p).
	if math.IsDeficient(2) { pass = pass + 1 }
	if math.IsDeficient(3) { pass = pass + 1 }
	if math.IsDeficient(5) { pass = pass + 1 }
	if math.IsDeficient(7) { pass = pass + 1 }
	if math.IsDeficient(13) { pass = pass + 1 }

	// More deficient.
	if math.IsDeficient(4) { pass = pass + 1 }     // proper = 1+2 = 3 < 4
	if math.IsDeficient(8) { pass = pass + 1 }     // 1+2+4 = 7 < 8
	if math.IsDeficient(10) { pass = pass + 1 }    // 1+2+5 = 8 < 10

	// Perfect — NOT deficient.
	if !math.IsDeficient(6) { pass = pass + 1 }
	if !math.IsDeficient(28) { pass = pass + 1 }

	// Abundant — NOT deficient.
	if !math.IsDeficient(12) { pass = pass + 1 }
	if !math.IsDeficient(24) { pass = pass + 1 }

	// Edge.
	if !math.IsDeficient(0) { pass = pass + 1 }
	if !math.IsDeficient(1) { pass = pass + 1 }
	if !math.IsDeficient(-7) { pass = pass + 1 }

	// Trichotomy: every n >= 2 is exactly one of {abundant, perfect, deficient}.
	var n int = 12
	var sum int = 0
	if math.IsAbundant(n) { sum = sum + 1 }
	if math.IsPerfect(n) { sum = sum + 1 }
	if math.IsDeficient(n) { sum = sum + 1 }
	if sum == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 30 { ret 42 }
	ret 0
}
