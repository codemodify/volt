package main
import "log"
import "slices"

// Positive test: slices.AccumulateMinInt + AccumulateProductInt.

fun main() int {
	var pass int = 0

	// AccumulateMinInt — basic descending.
	var a []int = new(5) []int{5, 4, 3, 2, 1}
	var pa []int = slices.AccumulateMinInt(a)
	if pa[0] == 5 { pass = pass + 1 }
	if pa[1] == 4 { pass = pass + 1 }
	if pa[2] == 3 { pass = pass + 1 }
	if pa[3] == 2 { pass = pass + 1 }
	if pa[4] == 1 { pass = pass + 1 }

	// AccumulateMinInt — out-of-order.
	var b []int = new(6) []int{3, 1, 4, 1, 5, 0}
	var pb []int = slices.AccumulateMinInt(b)
	if pb[0] == 3 { pass = pass + 1 }
	if pb[1] == 1 { pass = pass + 1 }
	if pb[2] == 1 { pass = pass + 1 }
	if pb[3] == 1 { pass = pass + 1 }
	if pb[4] == 1 { pass = pass + 1 }
	if pb[5] == 0 { pass = pass + 1 }

	// Empty.
	var e []int = new(0) []int{}
	var pe []int = slices.AccumulateMinInt(e)
	if len(pe) == 0 { pass = pass + 1 }

	// Single.
	var s []int = new(1) []int{42}
	var ps []int = slices.AccumulateMinInt(s)
	if ps[0] == 42 { pass = pass + 1 }

	// AccumulateProductInt — basic.
	var c []int = new(4) []int{2, 3, 4, 5}
	var pc []int = slices.AccumulateProductInt(c)
	if pc[0] == 2 { pass = pass + 1 }
	if pc[1] == 6 { pass = pass + 1 }
	if pc[2] == 24 { pass = pass + 1 }
	if pc[3] == 120 { pass = pass + 1 }

	// With a 0 mid-way → zeros from there on.
	var d []int = new(4) []int{2, 3, 0, 5}
	var pd []int = slices.AccumulateProductInt(d)
	if pd[0] == 2 { pass = pass + 1 }
	if pd[1] == 6 { pass = pass + 1 }
	if pd[2] == 0 { pass = pass + 1 }
	if pd[3] == 0 { pass = pass + 1 }

	// Negatives — sign flips.
	var n []int = new(3) []int{-2, 3, -4}
	var pn []int = slices.AccumulateProductInt(n)
	if pn[0] == -2 { pass = pass + 1 }
	if pn[1] == -6 { pass = pass + 1 }
	if pn[2] == 24 { pass = pass + 1 }

	// Empty product.
	var ee []int = new(0) []int{}
	var pee []int = slices.AccumulateProductInt(ee)
	if len(pee) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 25 { ret 42 }
	ret 0
}
