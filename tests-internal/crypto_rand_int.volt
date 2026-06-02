package main
import "log"
import "crypto/rand"

// Positive test: crypto/rand.Int(max) — bounded cryptographic
// random int. Each draw must be in [0, max). Verify uniform
// distribution coverage qualitatively over many draws.

fun main() int {
	var pass int = 0

	// max <= 0 edge cases.
	if rand.Int(0) == 0 { pass = pass + 1 }
	if rand.Int(-1) == 0 { pass = pass + 1 }

	// Single-bucket: every draw must be 0.
	var allZero bool = true
	for i := 0; i < 32; i++ {
		if rand.Int(1) != 0 { allZero = false }
	}
	if allZero { pass = pass + 1 }

	// Range: every draw must be in [0, 100).
	var inRange bool = true
	for i := 0; i < 200; i++ {
		var x int = rand.Int(100)
		if x < 0 { inRange = false }
		if x >= 100 { inRange = false }
	}
	if inRange { pass = pass + 1 }

	// Distribution: 200 draws of rand.Int(2) should produce at
	// least one 0 AND at least one 1 (probability of all-same
	// = 2 × 2^-200, negligibly small).
	var sawZero bool = false
	var sawOne bool = false
	for i := 0; i < 200; i++ {
		var x int = rand.Int(2)
		if x == 0 { sawZero = true }
		if x == 1 { sawOne = true }
	}
	if sawZero { pass = pass + 1 }
	if sawOne { pass = pass + 1 }

	// Independence: two consecutive draws of rand.Int(1<<20) almost
	// certainly differ. (P(equal) = 2^-20, negligibly small over
	// 50 trials.)
	var different bool = false
	for i := 0; i < 50; i++ {
		var a int = rand.Int(1048576)
		var b int = rand.Int(1048576)
		if a != b { different = true }
	}
	if different { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 7 { ret 42 }
	ret 0
}
