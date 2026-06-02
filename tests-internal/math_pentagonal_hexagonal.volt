package main
import "log"
import "math"

// Positive test: math.IsPentagonalInt + math.IsHexagonalInt.

fun main() int {
	var pass int = 0

	// Pentagonal: 0, 1, 5, 12, 22, 35, 51, 70, 92, 117, 145, 176, 210
	if math.IsPentagonalInt(0) { pass = pass + 1 }
	if math.IsPentagonalInt(1) { pass = pass + 1 }
	if math.IsPentagonalInt(5) { pass = pass + 1 }
	if math.IsPentagonalInt(12) { pass = pass + 1 }
	if math.IsPentagonalInt(22) { pass = pass + 1 }
	if math.IsPentagonalInt(35) { pass = pass + 1 }
	if math.IsPentagonalInt(51) { pass = pass + 1 }
	if math.IsPentagonalInt(70) { pass = pass + 1 }
	if math.IsPentagonalInt(92) { pass = pass + 1 }
	if math.IsPentagonalInt(117) { pass = pass + 1 }
	if math.IsPentagonalInt(145) { pass = pass + 1 }

	// Not pentagonal.
	if !math.IsPentagonalInt(2) { pass = pass + 1 }
	if !math.IsPentagonalInt(3) { pass = pass + 1 }
	if !math.IsPentagonalInt(6) { pass = pass + 1 }
	if !math.IsPentagonalInt(13) { pass = pass + 1 }
	if !math.IsPentagonalInt(100) { pass = pass + 1 }
	if !math.IsPentagonalInt(144) { pass = pass + 1 }

	// Negative.
	if !math.IsPentagonalInt(-5) { pass = pass + 1 }

	// Hexagonal: 0, 1, 6, 15, 28, 45, 66, 91, 120, 153, 190, 231, 276
	if math.IsHexagonalInt(0) { pass = pass + 1 }
	if math.IsHexagonalInt(1) { pass = pass + 1 }
	if math.IsHexagonalInt(6) { pass = pass + 1 }
	if math.IsHexagonalInt(15) { pass = pass + 1 }
	if math.IsHexagonalInt(28) { pass = pass + 1 }
	if math.IsHexagonalInt(45) { pass = pass + 1 }
	if math.IsHexagonalInt(66) { pass = pass + 1 }
	if math.IsHexagonalInt(91) { pass = pass + 1 }
	if math.IsHexagonalInt(120) { pass = pass + 1 }
	if math.IsHexagonalInt(153) { pass = pass + 1 }

	// Not hexagonal.
	if !math.IsHexagonalInt(2) { pass = pass + 1 }
	if !math.IsHexagonalInt(3) { pass = pass + 1 }
	if !math.IsHexagonalInt(5) { pass = pass + 1 }
	if !math.IsHexagonalInt(10) { pass = pass + 1 }
	if !math.IsHexagonalInt(21) { pass = pass + 1 }   // triangular but not hexagonal
	if !math.IsHexagonalInt(100) { pass = pass + 1 }

	// Negative.
	if !math.IsHexagonalInt(-6) { pass = pass + 1 }

	// Every hexagonal is also triangular.
	if math.IsTriangularInt(6) { pass = pass + 1 }
	if math.IsTriangularInt(28) { pass = pass + 1 }
	if math.IsTriangularInt(120) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 38 { ret 42 }
	ret 0
}
