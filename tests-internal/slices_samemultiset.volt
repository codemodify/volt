package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// SameMultisetInt — identical order.
	var a1 []int = new(3) []int { 1, 2, 3 }
	var b1 []int = new(3) []int { 1, 2, 3 }
	if slices.SameMultisetInt(a1, b1) { pass = pass + 1 }

	// Same multiset, different order.
	var a2 []int = new(3) []int { 1, 2, 3 }
	var b2 []int = new(3) []int { 3, 1, 2 }
	if slices.SameMultisetInt(a2, b2) { pass = pass + 1 }

	// Multiplicity matters.
	var a3 []int = new(4) []int { 1, 1, 2, 2 }
	var b3 []int = new(4) []int { 1, 2, 1, 2 }
	if slices.SameMultisetInt(a3, b3) { pass = pass + 1 }

	// Different multiplicities → false.
	var a4 []int = new(4) []int { 1, 1, 2, 3 }
	var b4 []int = new(4) []int { 1, 2, 2, 3 }
	if !slices.SameMultisetInt(a4, b4) { pass = pass + 1 }

	// Length mismatch → false.
	var a5 []int = new(3) []int { 1, 2, 3 }
	var b5 []int = new(2) []int { 1, 2 }
	if !slices.SameMultisetInt(a5, b5) { pass = pass + 1 }

	// Different values → false.
	var a6 []int = new(3) []int { 1, 2, 3 }
	var b6 []int = new(3) []int { 1, 2, 4 }
	if !slices.SameMultisetInt(a6, b6) { pass = pass + 1 }

	// Both empty → true (vacuous).
	var e1 []int = new(0) []int {}
	var e2 []int = new(0) []int {}
	if slices.SameMultisetInt(e1, e2) { pass = pass + 1 }

	// Single element.
	var s1 []int = new(1) []int { 42 }
	var s2 []int = new(1) []int { 42 }
	if slices.SameMultisetInt(s1, s2) { pass = pass + 1 }

	// Single different element.
	var s3 []int = new(1) []int { 42 }
	var s4 []int = new(1) []int { 43 }
	if !slices.SameMultisetInt(s3, s4) { pass = pass + 1 }

	// Negatives.
	var n1 []int = new(4) []int { -1, -2, 0, 1 }
	var n2 []int = new(4) []int { 1, 0, -2, -1 }
	if slices.SameMultisetInt(n1, n2) { pass = pass + 1 }

	// SameMultisetString.
	var sa1 []string = new(3) []string { "alpha", "beta", "gamma" }
	var sb1 []string = new(3) []string { "gamma", "alpha", "beta" }
	if slices.SameMultisetString(sa1, sb1) { pass = pass + 1 }

	// SameMultisetString — different counts.
	var sa2 []string = new(4) []string { "a", "a", "b", "c" }
	var sb2 []string = new(4) []string { "a", "b", "b", "c" }
	if !slices.SameMultisetString(sa2, sb2) { pass = pass + 1 }

	// SameMultisetString — empty.
	var se1 []string = new(0) []string {}
	var se2 []string = new(0) []string {}
	if slices.SameMultisetString(se1, se2) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
