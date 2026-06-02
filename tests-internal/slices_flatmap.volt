package main
import "log"
import "slices"

fun doubleExpand(x int) []int {
	var out []int = new(2) []int { x, x }
	ret out
}

fun rangeTo(x int) []int {
	if x <= 0 {
		var empty []int = new(0) []int {}
		ret empty
	}
	var out []int = new(x) []int {}
	for i := 0; i < x; i++ { out[i] = i }
	ret out
}

fun emptyExpand(x int) []int {
	var out []int = new(0) []int {}
	ret out
}

fun splitChars(s string) []string {
	var n int = len(s)
	var out []string = new(n) []string {}
	for i := 0; i < n; i++ {
		out[i] = chr(s[i])
	}
	ret out
}

fun keepSelf(s string) []string {
	var out []string = new(1) []string { "" + s }
	ret out
}

fun main() int {
	var pass int = 0

	// FlatMapInt — each elem → 2 copies.
	var in1 []int = new(3) []int { 1, 2, 3 }
	var out1 []int = slices.FlatMapInt(in1, doubleExpand)
	if len(out1) == 6 { pass = pass + 1 }
	if out1[0] == 1 { pass = pass + 1 }
	if out1[1] == 1 { pass = pass + 1 }
	if out1[2] == 2 { pass = pass + 1 }
	if out1[5] == 3 { pass = pass + 1 }

	// FlatMapInt — variable-sized expansions.
	// rangeTo(3) = [0,1,2]; rangeTo(2) = [0,1]; rangeTo(0) = [].
	var in2 []int = new(3) []int { 3, 2, 0 }
	var out2 []int = slices.FlatMapInt(in2, rangeTo)
	if len(out2) == 5 { pass = pass + 1 }
	if out2[0] == 0 { pass = pass + 1 }
	if out2[1] == 1 { pass = pass + 1 }
	if out2[2] == 2 { pass = pass + 1 }
	if out2[3] == 0 { pass = pass + 1 }
	if out2[4] == 1 { pass = pass + 1 }

	// FlatMapInt — every fn returns empty → total empty.
	var in3 []int = new(3) []int { 1, 2, 3 }
	var out3 []int = slices.FlatMapInt(in3, emptyExpand)
	if len(out3) == 0 { pass = pass + 1 }

	// FlatMapInt — empty input → empty output.
	var in4 []int = new(0) []int {}
	var out4 []int = slices.FlatMapInt(in4, doubleExpand)
	if len(out4) == 0 { pass = pass + 1 }

	// FlatMapString — split each word into chars.
	var in5 []string = new(2) []string { "ab", "cde" }
	var out5 []string = slices.FlatMapString(in5, splitChars)
	if len(out5) == 5 { pass = pass + 1 }
	if out5[0] == "a" { pass = pass + 1 }
	if out5[1] == "b" { pass = pass + 1 }
	if out5[2] == "c" { pass = pass + 1 }
	if out5[4] == "e" { pass = pass + 1 }

	// FlatMapString with identity-wrap-as-singleton is equivalent to input.
	var in6 []string = new(3) []string { "x", "y", "z" }
	var out6 []string = slices.FlatMapString(in6, keepSelf)
	if len(out6) == 3 { pass = pass + 1 }
	if out6[0] == "x" { pass = pass + 1 }
	if out6[2] == "z" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
