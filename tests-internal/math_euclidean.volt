package main
import "log"
import "math"

fun main() int {
	var pass int = 0

	// Same point → 0.
	if math.EuclideanSquaredDist(5, 5, 5, 5) == 0 { pass = pass + 1 }
	if math.EuclideanDist(5, 5, 5, 5) == 0 { pass = pass + 1 }

	// Pythagorean triple (3,4,5).
	if math.EuclideanSquaredDist(0, 0, 3, 4) == 25 { pass = pass + 1 }
	if math.EuclideanDist(0, 0, 3, 4) == 5 { pass = pass + 1 }

	// Pythagorean triple (5,12,13).
	if math.EuclideanSquaredDist(0, 0, 5, 12) == 169 { pass = pass + 1 }
	if math.EuclideanDist(0, 0, 5, 12) == 13 { pass = pass + 1 }

	// Pythagorean triple (8,15,17).
	if math.EuclideanSquaredDist(0, 0, 8, 15) == 289 { pass = pass + 1 }
	if math.EuclideanDist(0, 0, 8, 15) == 17 { pass = pass + 1 }

	// Pure horizontal / vertical (matches Manhattan for axis-aligned).
	if math.EuclideanSquaredDist(0, 0, 5, 0) == 25 { pass = pass + 1 }
	if math.EuclideanDist(0, 0, 5, 0) == 5 { pass = pass + 1 }
	if math.EuclideanSquaredDist(0, 0, 0, 7) == 49 { pass = pass + 1 }
	if math.EuclideanDist(0, 0, 0, 7) == 7 { pass = pass + 1 }

	// Symmetric (sign-independent).
	if math.EuclideanSquaredDist(3, 4, 0, 0) == 25 { pass = pass + 1 }
	if math.EuclideanSquaredDist(-3, -4, 0, 0) == 25 { pass = pass + 1 }
	if math.EuclideanSquaredDist(3, 4, -3, -4) == 100 { pass = pass + 1 }   // (6²+8²=100)

	// Non-trivial floor: dist between (0,0) and (1,1) → sqrt(2) ≈ 1.41 → floor 1.
	if math.EuclideanSquaredDist(0, 0, 1, 1) == 2 { pass = pass + 1 }
	if math.EuclideanDist(0, 0, 1, 1) == 1 { pass = pass + 1 }

	// dist between (0,0) and (2,2) → sqrt(8) ≈ 2.83 → floor 2.
	if math.EuclideanSquaredDist(0, 0, 2, 2) == 8 { pass = pass + 1 }
	if math.EuclideanDist(0, 0, 2, 2) == 2 { pass = pass + 1 }

	// Diagonal grid 10x10.
	if math.EuclideanSquaredDist(0, 0, 10, 10) == 200 { pass = pass + 1 }
	if math.EuclideanDist(0, 0, 10, 10) == 14 { pass = pass + 1 }   // sqrt(200) ≈ 14.14

	// Cross-property: EuclideanDist ≤ ManhattanDist (triangle inequality on dist metrics).
	if math.EuclideanDist(0, 0, 3, 4) <= math.ManhattanDist(0, 0, 3, 4) { pass = pass + 1 }
	if math.EuclideanDist(1, 2, 7, 8) <= math.ManhattanDist(1, 2, 7, 8) { pass = pass + 1 }

	// Cross-property: ChebyshevDist ≤ EuclideanDist.
	if math.ChebyshevDist(0, 0, 3, 4) <= math.EuclideanDist(0, 0, 3, 4) { pass = pass + 1 }

	// Use case: which of two points is closer?
	// p=(5,5); a=(0,0); b=(10,10)
	var dpa int = math.EuclideanSquaredDist(5, 5, 0, 0)   // 50
	var dpb int = math.EuclideanSquaredDist(5, 5, 10, 10)  // 50
	if dpa == dpb { pass = pass + 1 }   // equally far

	// p=(0,0); a=(3,4); b=(5,12)
	var dpa2 int = math.EuclideanSquaredDist(0, 0, 3, 4)
	var dpb2 int = math.EuclideanSquaredDist(0, 0, 5, 12)
	if dpa2 < dpb2 { pass = pass + 1 }   // 25 < 169

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
