package main
import "log"
import "slices"

// Positive test: slices.AccumulateInt + AccumulateMaxInt.

fun main() int {
	var pass int = 0

	// AccumulateInt basic.
	var a []int = new(5) []int{1, 2, 3, 4, 5}
	var pa []int = slices.AccumulateInt(a)
	if len(pa) == 5 { pass = pass + 1 }
	if pa[0] == 1 { pass = pass + 1 }
	if pa[1] == 3 { pass = pass + 1 }
	if pa[2] == 6 { pass = pass + 1 }
	if pa[3] == 10 { pass = pass + 1 }
	if pa[4] == 15 { pass = pass + 1 }

	// AccumulateInt with negatives.
	var b []int = new(4) []int{5, -2, 3, -1}
	var pb []int = slices.AccumulateInt(b)
	if pb[0] == 5 { pass = pass + 1 }
	if pb[1] == 3 { pass = pass + 1 }
	if pb[2] == 6 { pass = pass + 1 }
	if pb[3] == 5 { pass = pass + 1 }

	// Empty input.
	var e []int = new(0) []int{}
	var pe []int = slices.AccumulateInt(e)
	if len(pe) == 0 { pass = pass + 1 }

	// Single element.
	var s []int = new(1) []int{42}
	var ps []int = slices.AccumulateInt(s)
	if len(ps) == 1 { pass = pass + 1 }
	if ps[0] == 42 { pass = pass + 1 }

	// AccumulateMaxInt — running max.
	var c []int = new(6) []int{3, 1, 4, 1, 5, 2}
	var pc []int = slices.AccumulateMaxInt(c)
	if pc[0] == 3 { pass = pass + 1 }
	if pc[1] == 3 { pass = pass + 1 }
	if pc[2] == 4 { pass = pass + 1 }
	if pc[3] == 4 { pass = pass + 1 }
	if pc[4] == 5 { pass = pass + 1 }
	if pc[5] == 5 { pass = pass + 1 }

	// AccumulateMaxInt strictly increasing.
	var d []int = new(4) []int{1, 2, 3, 4}
	var pd []int = slices.AccumulateMaxInt(d)
	if pd[3] == 4 { pass = pass + 1 }

	// AccumulateMaxInt empty.
	var ee []int = new(0) []int{}
	var pee []int = slices.AccumulateMaxInt(ee)
	if len(pee) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
