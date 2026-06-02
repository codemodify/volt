package main
import "log"
import "slices"

// Positive test: slices.MinMaxByInt + slices.PadInt + slices.PadString.

fun abs(x int) int { if x < 0 { ret -x }; ret x }
fun ident(x int) int { ret x }

fun main() int {
	var pass int = 0

	// MinMaxByInt by absolute value.
	var a []int = new(5) []int{-7, 2, -3, 10, -1}
	var mn int = 0
	var mx int = 0
	mn, mx = slices.MinMaxByInt(a, abs)
	if mn == -1 { pass = pass + 1 }    // smallest |x|
	if mx == 10 { pass = pass + 1 }    // largest |x|

	// MinMaxByInt identity.
	var b []int = new(4) []int{4, 1, 7, 3}
	mn, mx = slices.MinMaxByInt(b, ident)
	if mn == 1 { pass = pass + 1 }
	if mx == 7 { pass = pass + 1 }

	// Single element.
	var sg []int = new(1) []int{42}
	mn, mx = slices.MinMaxByInt(sg, ident)
	if mn == 42 { pass = pass + 1 }
	if mx == 42 { pass = pass + 1 }

	// Empty.
	var em []int = new(0) []int{}
	mn, mx = slices.MinMaxByInt(em, ident)
	if mn == 0 { pass = pass + 1 }
	if mx == 0 { pass = pass + 1 }

	// PadInt extend.
	var p1 []int = slices.PadInt(new(3) []int{1, 2, 3}, 5, 0)
	if len(p1) == 5 { pass = pass + 1 }
	if p1[0] == 1 { pass = pass + 1 }
	if p1[2] == 3 { pass = pass + 1 }
	if p1[3] == 0 { pass = pass + 1 }
	if p1[4] == 0 { pass = pass + 1 }

	// PadInt truncate.
	var p2 []int = slices.PadInt(new(5) []int{1, 2, 3, 4, 5}, 3, 0)
	if len(p2) == 3 { pass = pass + 1 }
	if p2[0] == 1 { pass = pass + 1 }
	if p2[2] == 3 { pass = pass + 1 }

	// PadInt exact length.
	var p3 []int = slices.PadInt(new(3) []int{1, 2, 3}, 3, 99)
	if len(p3) == 3 { pass = pass + 1 }
	if p3[0] == 1 { pass = pass + 1 }

	// PadInt n=0 / negative.
	if len(slices.PadInt(new(2) []int{1, 2}, 0, 0)) == 0 { pass = pass + 1 }
	if len(slices.PadInt(new(2) []int{1, 2}, -1, 0)) == 0 { pass = pass + 1 }

	// PadInt empty input.
	var p4 []int = slices.PadInt(new(0) []int{}, 3, 7)
	if len(p4) == 3 { pass = pass + 1 }
	if p4[0] == 7 { pass = pass + 1 }
	if p4[2] == 7 { pass = pass + 1 }

	// PadString.
	var ps []string = slices.PadString(new(2) []string{"a", "b"}, 4, "x")
	if len(ps) == 4 { pass = pass + 1 }
	if ps[0] == "a" { pass = pass + 1 }
	if ps[2] == "x" { pass = pass + 1 }
	if ps[3] == "x" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 27 { ret 42 }
	ret 0
}
