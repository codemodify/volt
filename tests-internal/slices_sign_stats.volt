package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	if slices.CountPositiveInt(e) == 0 { pass = pass + 1 }
	var e2 []int = new(0) []int {}
	if slices.CountNegativeInt(e2) == 0 { pass = pass + 1 }
	var e3 []int = new(0) []int {}
	if slices.CountZeroInt(e3) == 0 { pass = pass + 1 }
	var e4 []int = new(0) []int {}
	if slices.SumPositiveInt(e4) == 0 { pass = pass + 1 }
	var e5 []int = new(0) []int {}
	if slices.SumNegativeInt(e5) == 0 { pass = pass + 1 }

	// All positive.
	var s1 []int = new(4) []int { 1, 2, 3, 4 }
	if slices.CountPositiveInt(s1) == 4 { pass = pass + 1 }
	var s1b []int = new(4) []int { 1, 2, 3, 4 }
	if slices.CountNegativeInt(s1b) == 0 { pass = pass + 1 }
	var s1c []int = new(4) []int { 1, 2, 3, 4 }
	if slices.CountZeroInt(s1c) == 0 { pass = pass + 1 }
	var s1d []int = new(4) []int { 1, 2, 3, 4 }
	if slices.SumPositiveInt(s1d) == 10 { pass = pass + 1 }
	var s1e []int = new(4) []int { 1, 2, 3, 4 }
	if slices.SumNegativeInt(s1e) == 0 { pass = pass + 1 }

	// All negative.
	var s2 []int = new(3) []int { -5, -10, -15 }
	if slices.CountPositiveInt(s2) == 0 { pass = pass + 1 }
	var s2b []int = new(3) []int { -5, -10, -15 }
	if slices.CountNegativeInt(s2b) == 3 { pass = pass + 1 }
	var s2c []int = new(3) []int { -5, -10, -15 }
	if slices.SumNegativeInt(s2c) == -30 { pass = pass + 1 }
	var s2d []int = new(3) []int { -5, -10, -15 }
	if slices.SumPositiveInt(s2d) == 0 { pass = pass + 1 }

	// All zeros.
	var s3 []int = new(5) []int { 0, 0, 0, 0, 0 }
	if slices.CountZeroInt(s3) == 5 { pass = pass + 1 }
	var s3b []int = new(5) []int { 0, 0, 0, 0, 0 }
	if slices.CountPositiveInt(s3b) == 0 { pass = pass + 1 }
	var s3c []int = new(5) []int { 0, 0, 0, 0, 0 }
	if slices.CountNegativeInt(s3c) == 0 { pass = pass + 1 }

	// Mixed signs.
	var s4 []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	if slices.CountPositiveInt(s4) == 2 { pass = pass + 1 }
	var s4b []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	if slices.CountNegativeInt(s4b) == 2 { pass = pass + 1 }
	var s4c []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	if slices.CountZeroInt(s4c) == 2 { pass = pass + 1 }
	var s4d []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	if slices.SumPositiveInt(s4d) == 8 { pass = pass + 1 }   // 3+5
	var s4e []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	if slices.SumNegativeInt(s4e) == -3 { pass = pass + 1 }   // -2-1

	// Cross-property: SumPositive + SumNegative == Sum (since zeros contribute 0).
	var s5 []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	var s5b []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	var s5c []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	var sp int = slices.SumPositiveInt(s5)
	var sn int = slices.SumNegativeInt(s5b)
	var total int = slices.SumInts(s5c)
	if sp + sn == total { pass = pass + 1 }

	// Cross-property: counts add up to len(s).
	var s6 []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	var s6b []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	var s6c []int = new(6) []int { -2, 0, 3, -1, 0, 5 }
	var cp int = slices.CountPositiveInt(s6)
	var cn int = slices.CountNegativeInt(s6b)
	var cz int = slices.CountZeroInt(s6c)
	if cp + cn + cz == 6 { pass = pass + 1 }

	// Use case: deposits vs withdrawals.
	var ledger []int = new(6) []int { 100, -50, 200, -75, 300, -25 }
	var ledger2 []int = new(6) []int { 100, -50, 200, -75, 300, -25 }
	var deposits int = slices.SumPositiveInt(ledger)
	var withdrawals int = slices.SumNegativeInt(ledger2)
	if deposits == 600 { pass = pass + 1 }
	if withdrawals == -150 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
