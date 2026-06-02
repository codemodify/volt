package main
import "log"
import "math"

// Positive test: math.TriangularInt + math.FibInt.

fun main() int {
	var pass int = 0

	// TriangularInt — basic.
	if math.TriangularInt(0) == 0 { pass = pass + 1 }
	if math.TriangularInt(1) == 1 { pass = pass + 1 }
	if math.TriangularInt(2) == 3 { pass = pass + 1 }   // 1+2
	if math.TriangularInt(3) == 6 { pass = pass + 1 }   // 1+2+3
	if math.TriangularInt(4) == 10 { pass = pass + 1 }
	if math.TriangularInt(5) == 15 { pass = pass + 1 }
	if math.TriangularInt(10) == 55 { pass = pass + 1 }
	if math.TriangularInt(100) == 5050 { pass = pass + 1 }   // Gauss

	// TriangularInt negative.
	if math.TriangularInt(-1) == 0 { pass = pass + 1 }
	if math.TriangularInt(-100) == 0 { pass = pass + 1 }

	// FibInt basic.
	if math.FibInt(0) == 0 { pass = pass + 1 }
	if math.FibInt(1) == 1 { pass = pass + 1 }
	if math.FibInt(2) == 1 { pass = pass + 1 }
	if math.FibInt(3) == 2 { pass = pass + 1 }
	if math.FibInt(4) == 3 { pass = pass + 1 }
	if math.FibInt(5) == 5 { pass = pass + 1 }
	if math.FibInt(6) == 8 { pass = pass + 1 }
	if math.FibInt(7) == 13 { pass = pass + 1 }
	if math.FibInt(10) == 55 { pass = pass + 1 }
	if math.FibInt(20) == 6765 { pass = pass + 1 }
	if math.FibInt(30) == 832040 { pass = pass + 1 }

	// FibInt larger.
	if math.FibInt(40) == 102334155 { pass = pass + 1 }
	if math.FibInt(50) == 12586269025 { pass = pass + 1 }

	// FibInt negative.
	if math.FibInt(-1) == 0 { pass = pass + 1 }
	if math.FibInt(-100) == 0 { pass = pass + 1 }

	// Recurrence sanity: F(n) = F(n-1) + F(n-2).
	if math.FibInt(15) == (math.FibInt(14) + math.FibInt(13)) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
