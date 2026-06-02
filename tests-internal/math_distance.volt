package main
import "log"
import "math"

fun main() int {
	var pass int = 0

	// ManhattanDist — same point.
	if math.ManhattanDist(0, 0, 0, 0) == 0 { pass = pass + 1 }
	if math.ManhattanDist(5, 5, 5, 5) == 0 { pass = pass + 1 }

	// Axial moves.
	if math.ManhattanDist(0, 0, 3, 0) == 3 { pass = pass + 1 }
	if math.ManhattanDist(0, 0, 0, 4) == 4 { pass = pass + 1 }

	// Diagonal.
	if math.ManhattanDist(0, 0, 3, 4) == 7 { pass = pass + 1 }

	// Negative coords.
	if math.ManhattanDist(-1, -1, 2, 3) == 7 { pass = pass + 1 }
	if math.ManhattanDist(-5, -5, 5, 5) == 20 { pass = pass + 1 }

	// Symmetric — Manhattan(a,b) == Manhattan(b,a).
	if math.ManhattanDist(1, 2, 4, 6) == math.ManhattanDist(4, 6, 1, 2) { pass = pass + 1 }

	// ChebyshevDist — same point.
	if math.ChebyshevDist(0, 0, 0, 0) == 0 { pass = pass + 1 }

	// Axial — equals the magnitude on that axis.
	if math.ChebyshevDist(0, 0, 3, 0) == 3 { pass = pass + 1 }
	if math.ChebyshevDist(0, 0, 0, 5) == 5 { pass = pass + 1 }

	// Pure diagonal — max(dx, dy).
	if math.ChebyshevDist(0, 0, 3, 4) == 4 { pass = pass + 1 }     // max(3, 4)
	if math.ChebyshevDist(0, 0, 7, 2) == 7 { pass = pass + 1 }

	// Equal dx and dy.
	if math.ChebyshevDist(0, 0, 5, 5) == 5 { pass = pass + 1 }

	// Negative coords.
	if math.ChebyshevDist(-3, -4, 0, 0) == 4 { pass = pass + 1 }   // max(3, 4)

	// Symmetric.
	if math.ChebyshevDist(1, 2, 4, 6) == math.ChebyshevDist(4, 6, 1, 2) { pass = pass + 1 }

	// Cross-check: Chebyshev ≤ Manhattan (always, for L∞ vs L1).
	if math.ChebyshevDist(2, 3, 9, 11) <= math.ManhattanDist(2, 3, 9, 11) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
