package main
import "log"
import "slices"

// Positive test: slices.MaxMinString + slices.VarianceIntScaled.

fun main() int {
	var pass int = 0

	// MaxMinString basic.
	var a []string = new(4) []string{"banana", "apple", "cherry", "date"}
	var mx string = ""
	var mn string = ""
	mx, mn = slices.MaxMinString(a)
	if mx == "date" { pass = pass + 1 }
	if mn == "apple" { pass = pass + 1 }

	// Single element.
	var sg []string = new(1) []string{"only"}
	mx, mn = slices.MaxMinString(sg)
	if mx == "only" { pass = pass + 1 }
	if mn == "only" { pass = pass + 1 }

	// All-same.
	var ss []string = new(3) []string{"x", "x", "x"}
	mx, mn = slices.MaxMinString(ss)
	if mx == "x" { pass = pass + 1 }
	if mn == "x" { pass = pass + 1 }

	// Empty.
	var em []string = new(0) []string{}
	mx, mn = slices.MaxMinString(em)
	if mx == "" { pass = pass + 1 }
	if mn == "" { pass = pass + 1 }

	// Length tie — lex order via prefix.
	var p []string = new(3) []string{"abc", "abcd", "ab"}
	mx, mn = slices.MaxMinString(p)
	if mx == "abcd" { pass = pass + 1 }
	if mn == "ab" { pass = pass + 1 }

	// VarianceIntScaled basic.
	// {2, 4, 4, 4, 5, 5, 7, 9} — mean = 5, deviations: 9+1+1+1+0+0+4+16 = 32.
	var v []int = new(8) []int{2, 4, 4, 4, 5, 5, 7, 9}
	if slices.VarianceIntScaled(v) == 32 { pass = pass + 1 }

	// All same → 0.
	var c []int = new(4) []int{5, 5, 5, 5}
	if slices.VarianceIntScaled(c) == 0 { pass = pass + 1 }

	// Single → 0 (vacuous).
	if slices.VarianceIntScaled(new(1) []int{42}) == 0 { pass = pass + 1 }

	// Empty → 0.
	if slices.VarianceIntScaled(new(0) []int{}) == 0 { pass = pass + 1 }

	// Symmetric — variance(s) == variance(reverse(s)).
	var asc []int = new(5) []int{1, 2, 3, 4, 5}
	var desc []int = new(5) []int{5, 4, 3, 2, 1}
	if slices.VarianceIntScaled(asc) == slices.VarianceIntScaled(desc) { pass = pass + 1 }

	// Shift-invariance — adding a constant doesn't change variance.
	var shifted []int = new(5) []int{101, 102, 103, 104, 105}
	if slices.VarianceIntScaled(asc) == slices.VarianceIntScaled(shifted) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
