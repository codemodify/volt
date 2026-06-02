package main
import "log"
import "slices"

fun main() int {
	var pass int = 0

	// Empty s.
	var e []int = new(0) []int {}
	var h0 []int = new(0) []int {}
	var t0 []int = new(0) []int {}
	h0, t0 = slices.SplitAtInt(e, 3)
	if len(h0) == 0 { pass = pass + 1 }
	if len(t0) == 0 { pass = pass + 1 }

	// Normal split.
	var s1 []int = new(5) []int { 10, 20, 30, 40, 50 }
	var h1 []int = new(0) []int {}
	var t1 []int = new(0) []int {}
	h1, t1 = slices.SplitAtInt(s1, 2)
	if len(h1) == 2 { pass = pass + 1 }
	if h1[0] == 10 { pass = pass + 1 }
	if h1[1] == 20 { pass = pass + 1 }
	if len(t1) == 3 { pass = pass + 1 }
	if t1[0] == 30 { pass = pass + 1 }
	if t1[1] == 40 { pass = pass + 1 }
	if t1[2] == 50 { pass = pass + 1 }

	// Split at 0.
	var s2 []int = new(3) []int { 1, 2, 3 }
	var h2 []int = new(0) []int {}
	var t2 []int = new(0) []int {}
	h2, t2 = slices.SplitAtInt(s2, 0)
	if len(h2) == 0 { pass = pass + 1 }
	if len(t2) == 3 { pass = pass + 1 }

	// Split at len(s).
	var s3 []int = new(3) []int { 1, 2, 3 }
	var h3 []int = new(0) []int {}
	var t3 []int = new(0) []int {}
	h3, t3 = slices.SplitAtInt(s3, 3)
	if len(h3) == 3 { pass = pass + 1 }
	if len(t3) == 0 { pass = pass + 1 }

	// Out-of-range n clamps.
	var s4 []int = new(3) []int { 1, 2, 3 }
	var h4 []int = new(0) []int {}
	var t4 []int = new(0) []int {}
	h4, t4 = slices.SplitAtInt(s4, -5)
	if len(h4) == 0 { pass = pass + 1 }
	if len(t4) == 3 { pass = pass + 1 }

	var s5 []int = new(3) []int { 1, 2, 3 }
	var h5 []int = new(0) []int {}
	var t5 []int = new(0) []int {}
	h5, t5 = slices.SplitAtInt(s5, 99)
	if len(h5) == 3 { pass = pass + 1 }
	if len(t5) == 0 { pass = pass + 1 }

	// Doesn't mutate s.
	var s6 []int = new(4) []int { 4, 1, 3, 2 }
	var _h []int = new(0) []int {}
	var _t []int = new(0) []int {}
	_h, _t = slices.SplitAtInt(s6, 2)
	if s6[0] == 4 { pass = pass + 1 }
	if s6[1] == 1 { pass = pass + 1 }
	if s6[2] == 3 { pass = pass + 1 }
	if s6[3] == 2 { pass = pass + 1 }

	// String variant.
	var ss []string = new(4) []string { "a", "b", "c", "d" }
	var sh []string = new(0) []string {}
	var st []string = new(0) []string {}
	sh, st = slices.SplitAtString(ss, 2)
	if len(sh) == 2 { pass = pass + 1 }
	if sh[0] == "a" { pass = pass + 1 }
	if sh[1] == "b" { pass = pass + 1 }
	if len(st) == 2 { pass = pass + 1 }
	if st[0] == "c" { pass = pass + 1 }
	if st[1] == "d" { pass = pass + 1 }

	// Split in half use case.
	var data []int = new(6) []int { 1, 2, 3, 4, 5, 6 }
	var leftH []int = new(0) []int {}
	var rightH []int = new(0) []int {}
	leftH, rightH = slices.SplitAtInt(data, 3)
	if len(leftH) == 3 { pass = pass + 1 }
	if len(rightH) == 3 { pass = pass + 1 }
	if leftH[2] == 3 { pass = pass + 1 }
	if rightH[0] == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 31 { ret 42 }
	ret 0
}
