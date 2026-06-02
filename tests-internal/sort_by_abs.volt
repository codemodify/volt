package main
import "log"
import "sort"

fun main() int {
	var pass int = 0

	// Empty.
	var e []int = new(0) []int {}
	e = sort.IntsByAbs(e)
	if len(e) == 0 { pass = pass + 1 }

	// Single.
	var s1 []int = new(1) []int { -42 }
	s1 = sort.IntsByAbs(s1)
	if s1[0] == -42 { pass = pass + 1 }

	// All positive.
	var s2 []int = new(4) []int { 3, 1, 4, 2 }
	s2 = sort.IntsByAbs(s2)
	if s2[0] == 1 { pass = pass + 1 }
	if s2[1] == 2 { pass = pass + 1 }
	if s2[2] == 3 { pass = pass + 1 }
	if s2[3] == 4 { pass = pass + 1 }

	// Mixed signs — smallest magnitude first, sign preserved.
	var s3 []int = new(5) []int { -5, 3, -2, 7, -1 }
	s3 = sort.IntsByAbs(s3)
	if s3[0] == -1 { pass = pass + 1 }
	if s3[1] == -2 { pass = pass + 1 }
	if s3[2] == 3 { pass = pass + 1 }
	if s3[3] == -5 { pass = pass + 1 }
	if s3[4] == 7 { pass = pass + 1 }

	// Stable tie (equal magnitudes).
	var s4 []int = new(4) []int { -3, 3, -3, 3 }
	s4 = sort.IntsByAbs(s4)
	if s4[0] == -3 { pass = pass + 1 }
	if s4[1] == 3 { pass = pass + 1 }
	if s4[2] == -3 { pass = pass + 1 }
	if s4[3] == 3 { pass = pass + 1 }

	// Descending.
	var s5 []int = new(5) []int { -5, 3, -2, 7, -1 }
	s5 = sort.IntsByAbsDesc(s5)
	if s5[0] == 7 { pass = pass + 1 }
	if s5[1] == -5 { pass = pass + 1 }
	if s5[2] == 3 { pass = pass + 1 }
	if s5[3] == -2 { pass = pass + 1 }
	if s5[4] == -1 { pass = pass + 1 }

	// All zeros stable.
	var s6 []int = new(3) []int { 0, 0, 0 }
	s6 = sort.IntsByAbs(s6)
	if s6[0] == 0 { pass = pass + 1 }

	// Zero among others — zero first ascending.
	var s7 []int = new(4) []int { -3, 0, 5, -1 }
	s7 = sort.IntsByAbs(s7)
	if s7[0] == 0 { pass = pass + 1 }
	if s7[1] == -1 { pass = pass + 1 }

	// Use case: residuals closest-to-zero first.
	var residuals []int = new(5) []int { 10, -3, 8, -2, 5 }
	residuals = sort.IntsByAbs(residuals)
	if residuals[0] == -2 { pass = pass + 1 }
	if residuals[1] == -3 { pass = pass + 1 }
	if residuals[2] == 5 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
