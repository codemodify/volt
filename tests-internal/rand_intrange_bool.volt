package main
import "log"
import "crypto/rand"

fun main() int {
	var pass int = 0

	// IntRange — sample many; all should be in [lo, hi).
	var lo int = 100
	var hi int = 200
	var allInRange bool = true
	for i := 0; i < 200; i++ {
		var v int = rand.IntRange(lo, hi)
		if v < lo { allInRange = false }
		if v >= hi { allInRange = false }
	}
	if allInRange { pass = pass + 1 }

	// IntRange — empty range returns lo.
	if rand.IntRange(5, 5) == 5 { pass = pass + 1 }
	if rand.IntRange(10, 3) == 10 { pass = pass + 1 }

	// IntRange — single-value range returns that value.
	if rand.IntRange(7, 8) == 7 { pass = pass + 1 }

	// IntRange — covers both lo and hi-1 in enough samples.
	var sawLo bool = false
	var sawTop bool = false
	for i := 0; i < 1000; i++ {
		var v int = rand.IntRange(0, 5)
		if v == 0 { sawLo = true }
		if v == 4 { sawTop = true }
	}
	if sawLo { pass = pass + 1 }
	if sawTop { pass = pass + 1 }

	// IntRange — negative lo.
	var allInNeg bool = true
	for i := 0; i < 100; i++ {
		var v int = rand.IntRange(-10, 0)
		if v < -10 { allInNeg = false }
		if v >= 0 { allInNeg = false }
	}
	if allInNeg { pass = pass + 1 }

	// Bool — produces both values over many samples.
	var sawTrue bool = false
	var sawFalse bool = false
	for i := 0; i < 100; i++ {
		var b bool = rand.Bool()
		if b { sawTrue = true } else { sawFalse = true }
	}
	if sawTrue { pass = pass + 1 }
	if sawFalse { pass = pass + 1 }

	// Bool — calls return bool (sanity: at least one true and one false somewhere).
	var anyDifferent bool = false
	var prev bool = rand.Bool()
	for i := 0; i < 100; i++ {
		var cur bool = rand.Bool()
		if cur != prev { anyDifferent = true }
		prev = cur
	}
	if anyDifferent { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
