package main
import "log"
import "slices"

// Positive test: slices.MinMaxInts + slices.MinMaxStrings.

fun main() int {
	var pass int = 0

	var lo int = 0
	var hi int = 0

	// MinMaxInts — basic.
	lo, hi = slices.MinMaxInts(new(5) []int { 3, 1, 4, 1, 5 })
	if lo == 1 { pass = pass + 1 }
	if hi == 5 { pass = pass + 1 }

	// MinMaxInts — already sorted ascending.
	lo, hi = slices.MinMaxInts(new(4) []int { 1, 2, 3, 4 })
	if lo == 1 { pass = pass + 1 }
	if hi == 4 { pass = pass + 1 }

	// MinMaxInts — single element.
	lo, hi = slices.MinMaxInts(new(1) []int { 42 })
	if lo == 42 { pass = pass + 1 }
	if hi == 42 { pass = pass + 1 }

	// MinMaxInts — negatives.
	lo, hi = slices.MinMaxInts(new(4) []int { -5, -1, -3, 0 })
	if lo == -5 { pass = pass + 1 }
	if hi == 0 { pass = pass + 1 }

	// MinMaxInts — mixed positive/negative.
	lo, hi = slices.MinMaxInts(new(5) []int { -10, 0, 5, -7, 12 })
	if lo == -10 { pass = pass + 1 }
	if hi == 12 { pass = pass + 1 }

	// MinMaxInts — all identical.
	lo, hi = slices.MinMaxInts(new(3) []int { 7, 7, 7 })
	if lo == 7 { pass = pass + 1 }
	if hi == 7 { pass = pass + 1 }

	// MinMaxInts — empty returns (0, 0).
	lo, hi = slices.MinMaxInts(new(0) []int {})
	if lo == 0 { pass = pass + 1 }
	if hi == 0 { pass = pass + 1 }

	// MinMaxInts agrees with separate Min/Max calls.
	var sample []int = new(6) []int { 9, 2, 8, 3, 7, 5 }
	lo, hi = slices.MinMaxInts(sample)
	if lo == slices.MinInts(sample) { pass = pass + 1 }
	if hi == slices.MaxInts(sample) { pass = pass + 1 }

	var sLo string = ""
	var sHi string = ""

	// MinMaxStrings — basic alphabetical.
	sLo, sHi = slices.MinMaxStrings(new(4) []string { "banana", "apple", "cherry", "date" })
	if sLo == "apple" { pass = pass + 1 }
	if sHi == "date" { pass = pass + 1 }

	// MinMaxStrings — single element.
	sLo, sHi = slices.MinMaxStrings(new(1) []string { "lonely" })
	if sLo == "lonely" { pass = pass + 1 }
	if sHi == "lonely" { pass = pass + 1 }

	// MinMaxStrings — empty.
	sLo, sHi = slices.MinMaxStrings(new(0) []string {})
	if sLo == "" { pass = pass + 1 }
	if sHi == "" { pass = pass + 1 }

	// MinMaxStrings — prefix-tie shorter wins.
	sLo, sHi = slices.MinMaxStrings(new(3) []string { "foobar", "foo", "foobaz" })
	if sLo == "foo" { pass = pass + 1 }
	if sHi == "foobaz" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
