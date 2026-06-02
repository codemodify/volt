package main
import "log"
import "math"

// Positive test: math.IsTriangularInt + math.IsFibonacciInt.

fun main() int {
	var pass int = 0

	// Triangular — first several.
	if math.IsTriangularInt(0) { pass = pass + 1 }
	if math.IsTriangularInt(1) { pass = pass + 1 }
	if math.IsTriangularInt(3) { pass = pass + 1 }
	if math.IsTriangularInt(6) { pass = pass + 1 }
	if math.IsTriangularInt(10) { pass = pass + 1 }
	if math.IsTriangularInt(15) { pass = pass + 1 }
	if math.IsTriangularInt(21) { pass = pass + 1 }
	if math.IsTriangularInt(28) { pass = pass + 1 }
	if math.IsTriangularInt(45) { pass = pass + 1 }
	if math.IsTriangularInt(55) { pass = pass + 1 }
	if math.IsTriangularInt(5050) { pass = pass + 1 }   // T(100)

	// Not triangular.
	if !math.IsTriangularInt(2) { pass = pass + 1 }
	if !math.IsTriangularInt(4) { pass = pass + 1 }
	if !math.IsTriangularInt(7) { pass = pass + 1 }
	if !math.IsTriangularInt(11) { pass = pass + 1 }
	if !math.IsTriangularInt(20) { pass = pass + 1 }
	if !math.IsTriangularInt(100) { pass = pass + 1 }

	// Negatives.
	if !math.IsTriangularInt(-3) { pass = pass + 1 }

	// Fibonacci — first several.
	if math.IsFibonacciInt(0) { pass = pass + 1 }
	if math.IsFibonacciInt(1) { pass = pass + 1 }
	if math.IsFibonacciInt(2) { pass = pass + 1 }
	if math.IsFibonacciInt(3) { pass = pass + 1 }
	if math.IsFibonacciInt(5) { pass = pass + 1 }
	if math.IsFibonacciInt(8) { pass = pass + 1 }
	if math.IsFibonacciInt(13) { pass = pass + 1 }
	if math.IsFibonacciInt(21) { pass = pass + 1 }
	if math.IsFibonacciInt(34) { pass = pass + 1 }
	if math.IsFibonacciInt(55) { pass = pass + 1 }
	if math.IsFibonacciInt(144) { pass = pass + 1 }

	// Not Fibonacci.
	if !math.IsFibonacciInt(4) { pass = pass + 1 }
	if !math.IsFibonacciInt(6) { pass = pass + 1 }
	if !math.IsFibonacciInt(7) { pass = pass + 1 }
	if !math.IsFibonacciInt(9) { pass = pass + 1 }
	if !math.IsFibonacciInt(11) { pass = pass + 1 }
	if !math.IsFibonacciInt(100) { pass = pass + 1 }

	// Negatives.
	if !math.IsFibonacciInt(-5) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 36 { ret 42 }
	ret 0
}
