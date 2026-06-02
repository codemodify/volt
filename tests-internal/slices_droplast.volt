package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// DropLastInts — basic.
	var a []int = new(5) []int { 1, 2, 3, 4, 5 }
	var r1 []int = slices.DropLastInts(a, 2)
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == 1 { pass = pass + 1 }
	if r1[2] == 3 { pass = pass + 1 }

	// Drop 0.
	var a2 []int = new(3) []int { 10, 20, 30 }
	var r2 []int = slices.DropLastInts(a2, 0)
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 10 { pass = pass + 1 }
	if r2[2] == 30 { pass = pass + 1 }

	// Negative n → copy of s.
	var a3 []int = new(3) []int { 1, 2, 3 }
	var r3 []int = slices.DropLastInts(a3, -5)
	if len(r3) == 3 { pass = pass + 1 }

	// Drop all.
	var a4 []int = new(3) []int { 1, 2, 3 }
	var r4 []int = slices.DropLastInts(a4, 3)
	if len(r4) == 0 { pass = pass + 1 }

	// Drop more than length.
	var a5 []int = new(3) []int { 1, 2, 3 }
	var r5 []int = slices.DropLastInts(a5, 100)
	if len(r5) == 0 { pass = pass + 1 }

	// Empty input.
	var empty []int = new(0) []int {}
	var r6 []int = slices.DropLastInts(empty, 2)
	if len(r6) == 0 { pass = pass + 1 }

	// Drop 1 — common "all but last" use.
	var a6 []int = new(4) []int { 10, 20, 30, 40 }
	var r7 []int = slices.DropLastInts(a6, 1)
	if len(r7) == 3 { pass = pass + 1 }
	if r7[2] == 30 { pass = pass + 1 }

	// DropLastStrings — basic.
	var s []string = new(4) []string { "alpha", "beta", "gamma", "delta" }
	var rs1 []string = slices.DropLastStrings(s, 1)
	if len(rs1) == 3 { pass = pass + 1 }
	if rs1[0] == "alpha" { pass = pass + 1 }
	if rs1[2] == "gamma" { pass = pass + 1 }

	// DropLastStrings — drop all.
	var s2 []string = new(2) []string { "x", "y" }
	var rs2 []string = slices.DropLastStrings(s2, 2)
	if len(rs2) == 0 { pass = pass + 1 }

	// DropLastStrings — n <= 0.
	var s3 []string = new(2) []string { "x", "y" }
	var rs3 []string = slices.DropLastStrings(s3, 0)
	if len(rs3) == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
