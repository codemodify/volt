package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty.
	var e []string = new(0) []string {}
	var r1 []int = slices.LengthsString(e)
	if len(r1) == 0 { pass = pass + 1 }
	var e2 []string = new(0) []string {}
	if slices.TotalLenString(e2) == 0 { pass = pass + 1 }

	// Single.
	var s1 []string = new(1) []string { "hello" }
	var r2 []int = slices.LengthsString(s1)
	if len(r2) == 1 { pass = pass + 1 }
	if r2[0] == 5 { pass = pass + 1 }
	var s1b []string = new(1) []string { "hello" }
	if slices.TotalLenString(s1b) == 5 { pass = pass + 1 }

	// Multi.
	var s2 []string = new(4) []string { "a", "bb", "ccc", "dddd" }
	var r3 []int = slices.LengthsString(s2)
	if len(r3) == 4 { pass = pass + 1 }
	if r3[0] == 1 { pass = pass + 1 }
	if r3[1] == 2 { pass = pass + 1 }
	if r3[2] == 3 { pass = pass + 1 }
	if r3[3] == 4 { pass = pass + 1 }

	var s2b []string = new(4) []string { "a", "bb", "ccc", "dddd" }
	if slices.TotalLenString(s2b) == 10 { pass = pass + 1 }

	// Empty strings present.
	var s3 []string = new(3) []string { "", "x", "" }
	var r4 []int = slices.LengthsString(s3)
	if r4[0] == 0 { pass = pass + 1 }
	if r4[1] == 1 { pass = pass + 1 }
	if r4[2] == 0 { pass = pass + 1 }
	var s3b []string = new(3) []string { "", "x", "" }
	if slices.TotalLenString(s3b) == 1 { pass = pass + 1 }

	// All same length.
	var s4 []string = new(3) []string { "aaa", "bbb", "ccc" }
	var r5 []int = slices.LengthsString(s4)
	if r5[0] == 3 { pass = pass + 1 }
	if r5[1] == 3 { pass = pass + 1 }
	if r5[2] == 3 { pass = pass + 1 }
	var s4b []string = new(3) []string { "aaa", "bbb", "ccc" }
	if slices.TotalLenString(s4b) == 9 { pass = pass + 1 }

	// Doesn't mutate.
	var s5 []string = new(3) []string { "hi", "world", "x" }
	var _l []int = slices.LengthsString(s5)
	if s5[0] == "hi" { pass = pass + 1 }
	if s5[1] == "world" { pass = pass + 1 }
	if s5[2] == "x" { pass = pass + 1 }

	// Cross-property: TotalLenString == SumInts(LengthsString).
	var s6 []string = new(5) []string { "alpha", "bravo", "charlie", "delta", "echo" }
	var s6b []string = new(5) []string { "alpha", "bravo", "charlie", "delta", "echo" }
	var lens []int = slices.LengthsString(s6)
	if slices.TotalLenString(s6b) == slices.SumInts(lens) { pass = pass + 1 }

	// Cross-property: MaxLenString == max(LengthsString).
	var s7 []string = new(4) []string { "x", "yy", "zzz", "ww" }
	var s7b []string = new(4) []string { "x", "yy", "zzz", "ww" }
	var lens2 []int = slices.LengthsString(s7)
	if slices.MaxLenString(s7b) == slices.MaxInts(lens2) { pass = pass + 1 }

	// Buffer pre-allocation use case.
	var lines []string = new(4) []string { "line 1\n", "line 2\n", "line 3\n", "line 4\n" }
	if slices.TotalLenString(lines) == 28 { pass = pass + 1 }   // 7 bytes each × 4

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
