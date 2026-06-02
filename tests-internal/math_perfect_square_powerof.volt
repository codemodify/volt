package main
import "log"
import "math"

// Positive test: math.IsPerfectSquare + math.IsPowerOf.

fun main() int {
	var pass int = 0

	// Perfect squares.
	if math.IsPerfectSquare(0) { pass = pass + 1 }
	if math.IsPerfectSquare(1) { pass = pass + 1 }
	if math.IsPerfectSquare(4) { pass = pass + 1 }
	if math.IsPerfectSquare(9) { pass = pass + 1 }
	if math.IsPerfectSquare(16) { pass = pass + 1 }
	if math.IsPerfectSquare(100) { pass = pass + 1 }
	if math.IsPerfectSquare(10000) { pass = pass + 1 }
	if math.IsPerfectSquare(9801) { pass = pass + 1 }   // 99^2

	// Non-squares.
	if !math.IsPerfectSquare(2) { pass = pass + 1 }
	if !math.IsPerfectSquare(3) { pass = pass + 1 }
	if !math.IsPerfectSquare(5) { pass = pass + 1 }
	if !math.IsPerfectSquare(10) { pass = pass + 1 }
	if !math.IsPerfectSquare(99) { pass = pass + 1 }
	if !math.IsPerfectSquare(1000) { pass = pass + 1 }

	// Negatives.
	if !math.IsPerfectSquare(-1) { pass = pass + 1 }
	if !math.IsPerfectSquare(-100) { pass = pass + 1 }

	// IsPowerOf base 3.
	if math.IsPowerOf(1, 3) { pass = pass + 1 }       // 3^0
	if math.IsPowerOf(3, 3) { pass = pass + 1 }
	if math.IsPowerOf(9, 3) { pass = pass + 1 }
	if math.IsPowerOf(27, 3) { pass = pass + 1 }
	if math.IsPowerOf(81, 3) { pass = pass + 1 }

	// Not powers of 3.
	if !math.IsPowerOf(2, 3) { pass = pass + 1 }
	if !math.IsPowerOf(6, 3) { pass = pass + 1 }
	if !math.IsPowerOf(28, 3) { pass = pass + 1 }

	// IsPowerOf base 10.
	if math.IsPowerOf(1, 10) { pass = pass + 1 }
	if math.IsPowerOf(10, 10) { pass = pass + 1 }
	if math.IsPowerOf(100, 10) { pass = pass + 1 }
	if math.IsPowerOf(1000, 10) { pass = pass + 1 }
	if !math.IsPowerOf(99, 10) { pass = pass + 1 }
	if !math.IsPowerOf(11, 10) { pass = pass + 1 }

	// Edge: base < 2.
	if !math.IsPowerOf(1, 1) { pass = pass + 1 }
	if !math.IsPowerOf(1, 0) { pass = pass + 1 }
	if !math.IsPowerOf(1, -2) { pass = pass + 1 }

	// Edge: value <= 0.
	if !math.IsPowerOf(0, 2) { pass = pass + 1 }
	if !math.IsPowerOf(-4, 2) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 35 { ret 42 }
	ret 0
}
