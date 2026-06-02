package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty → all return true vacuously.
	var e []int = new(0) []int {}
	if slices.AllPositiveInt(e) { pass = pass + 1 }
	var e2 []int = new(0) []int {}
	if slices.AllNegativeInt(e2) { pass = pass + 1 }
	var e3 []int = new(0) []int {}
	if slices.AllNonNegativeInt(e3) { pass = pass + 1 }
	var e4 []int = new(0) []int {}
	if slices.AllNonZeroInt(e4) { pass = pass + 1 }

	// All positive.
	var s1 []int = new(4) []int { 1, 2, 3, 4 }
	if slices.AllPositiveInt(s1) { pass = pass + 1 }
	var s1b []int = new(4) []int { 1, 2, 3, 4 }
	if !slices.AllNegativeInt(s1b) { pass = pass + 1 }
	var s1c []int = new(4) []int { 1, 2, 3, 4 }
	if slices.AllNonNegativeInt(s1c) { pass = pass + 1 }
	var s1d []int = new(4) []int { 1, 2, 3, 4 }
	if slices.AllNonZeroInt(s1d) { pass = pass + 1 }

	// One zero kills AllPositive but not AllNonNegative.
	var s2 []int = new(4) []int { 1, 0, 3, 4 }
	if !slices.AllPositiveInt(s2) { pass = pass + 1 }
	var s2b []int = new(4) []int { 1, 0, 3, 4 }
	if slices.AllNonNegativeInt(s2b) { pass = pass + 1 }
	var s2c []int = new(4) []int { 1, 0, 3, 4 }
	if !slices.AllNonZeroInt(s2c) { pass = pass + 1 }

	// All zero.
	var s3 []int = new(3) []int { 0, 0, 0 }
	if !slices.AllPositiveInt(s3) { pass = pass + 1 }
	var s3b []int = new(3) []int { 0, 0, 0 }
	if !slices.AllNegativeInt(s3b) { pass = pass + 1 }
	var s3c []int = new(3) []int { 0, 0, 0 }
	if slices.AllNonNegativeInt(s3c) { pass = pass + 1 }
	var s3d []int = new(3) []int { 0, 0, 0 }
	if !slices.AllNonZeroInt(s3d) { pass = pass + 1 }

	// All negative.
	var s4 []int = new(3) []int { -1, -2, -3 }
	if !slices.AllPositiveInt(s4) { pass = pass + 1 }
	var s4b []int = new(3) []int { -1, -2, -3 }
	if slices.AllNegativeInt(s4b) { pass = pass + 1 }
	var s4c []int = new(3) []int { -1, -2, -3 }
	if !slices.AllNonNegativeInt(s4c) { pass = pass + 1 }
	var s4d []int = new(3) []int { -1, -2, -3 }
	if slices.AllNonZeroInt(s4d) { pass = pass + 1 }

	// Mixed signs.
	var s5 []int = new(4) []int { -1, 2, -3, 4 }
	if !slices.AllPositiveInt(s5) { pass = pass + 1 }
	var s5b []int = new(4) []int { -1, 2, -3, 4 }
	if !slices.AllNegativeInt(s5b) { pass = pass + 1 }
	var s5c []int = new(4) []int { -1, 2, -3, 4 }
	if slices.AllNonZeroInt(s5c) { pass = pass + 1 }

	// Single positive.
	var s6 []int = new(1) []int { 5 }
	if slices.AllPositiveInt(s6) { pass = pass + 1 }

	// Use case: divide-by-zero pre-flight.
	var divisors []int = new(4) []int { 2, 3, 4, 5 }
	if slices.AllNonZeroInt(divisors) { pass = pass + 1 }
	var badDiv []int = new(4) []int { 2, 0, 4, 5 }
	if !slices.AllNonZeroInt(badDiv) { pass = pass + 1 }

	// Use case: "amounts must be positive".
	var amounts []int = new(3) []int { 100, 200, 300 }
	if slices.AllPositiveInt(amounts) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
