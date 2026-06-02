package main
import "log"
import "math"

// Positive test: math.PrimeFactorsInt + math.IsPowerOfTwo.

fun main() int {
	var pass int = 0

	// PrimeFactorsInt — composite with multiplicity.
	var f12 []int = math.PrimeFactorsInt(12)
	if len(f12) == 3 { pass = pass + 1 }
	if f12[0] == 2 { pass = pass + 1 }
	if f12[1] == 2 { pass = pass + 1 }
	if f12[2] == 3 { pass = pass + 1 }

	// 60 = 2 * 2 * 3 * 5.
	var f60 []int = math.PrimeFactorsInt(60)
	if len(f60) == 4 { pass = pass + 1 }
	if f60[0] == 2 { pass = pass + 1 }
	if f60[1] == 2 { pass = pass + 1 }
	if f60[2] == 3 { pass = pass + 1 }
	if f60[3] == 5 { pass = pass + 1 }

	// Prime — single factor.
	var f7 []int = math.PrimeFactorsInt(7)
	if len(f7) == 1 { pass = pass + 1 }
	if f7[0] == 7 { pass = pass + 1 }

	// Large prime.
	var f9973 []int = math.PrimeFactorsInt(9973)
	if len(f9973) == 1 { pass = pass + 1 }
	if f9973[0] == 9973 { pass = pass + 1 }

	// 2^5 = 32 — five 2s.
	var f32 []int = math.PrimeFactorsInt(32)
	if len(f32) == 5 { pass = pass + 1 }
	if f32[0] == 2 { pass = pass + 1 }
	if f32[4] == 2 { pass = pass + 1 }

	// 1, 0, negative → empty.
	if len(math.PrimeFactorsInt(1)) == 0 { pass = pass + 1 }
	if len(math.PrimeFactorsInt(0)) == 0 { pass = pass + 1 }
	if len(math.PrimeFactorsInt(-12)) == 0 { pass = pass + 1 }

	// 2 itself.
	var f2 []int = math.PrimeFactorsInt(2)
	if len(f2) == 1 { pass = pass + 1 }
	if f2[0] == 2 { pass = pass + 1 }

	// IsPowerOfTwo positives.
	if math.IsPowerOfTwo(1) { pass = pass + 1 }
	if math.IsPowerOfTwo(2) { pass = pass + 1 }
	if math.IsPowerOfTwo(4) { pass = pass + 1 }
	if math.IsPowerOfTwo(1024) { pass = pass + 1 }
	if math.IsPowerOfTwo(65536) { pass = pass + 1 }

	// IsPowerOfTwo negatives.
	if !math.IsPowerOfTwo(0) { pass = pass + 1 }
	if !math.IsPowerOfTwo(3) { pass = pass + 1 }
	if !math.IsPowerOfTwo(6) { pass = pass + 1 }
	if !math.IsPowerOfTwo(100) { pass = pass + 1 }
	if !math.IsPowerOfTwo(-4) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 31 { ret 42 }
	ret 0
}
