package main
import "log"
import "math"

// Positive test: math.GcdInts + math.LcmInts.

fun main() int {
	var pass int = 0

	// GcdInts — basic.
	var a []int = new(3) []int{12, 18, 24}
	if math.GcdInts(a) == 6 { pass = pass + 1 }

	// GcdInts pairwise coprime → 1.
	var b []int = new(3) []int{7, 11, 13}
	if math.GcdInts(b) == 1 { pass = pass + 1 }

	// GcdInts all same → that value.
	var c []int = new(4) []int{15, 15, 15, 15}
	if math.GcdInts(c) == 15 { pass = pass + 1 }

	// GcdInts single → AbsInt.
	var d []int = new(1) []int{42}
	if math.GcdInts(d) == 42 { pass = pass + 1 }

	var dn []int = new(1) []int{-42}
	if math.GcdInts(dn) == 42 { pass = pass + 1 }

	// GcdInts empty → 0.
	var e []int = new(0) []int{}
	if math.GcdInts(e) == 0 { pass = pass + 1 }

	// GcdInts with 0 in input — GcdInt(g, 0) = |g|.
	var f []int = new(3) []int{0, 12, 18}
	if math.GcdInts(f) == 6 { pass = pass + 1 }

	// GcdInts with negatives.
	var g []int = new(3) []int{-12, -18, -24}
	if math.GcdInts(g) == 6 { pass = pass + 1 }

	// LcmInts — basic.
	var la []int = new(3) []int{2, 3, 4}
	if math.LcmInts(la) == 12 { pass = pass + 1 }

	// LcmInts pairwise coprime → product.
	var lb []int = new(3) []int{2, 3, 5}
	if math.LcmInts(lb) == 30 { pass = pass + 1 }

	// LcmInts all same → that value.
	var lc []int = new(4) []int{7, 7, 7, 7}
	if math.LcmInts(lc) == 7 { pass = pass + 1 }

	// LcmInts single.
	var ld []int = new(1) []int{99}
	if math.LcmInts(ld) == 99 { pass = pass + 1 }

	// LcmInts empty → 0.
	var le []int = new(0) []int{}
	if math.LcmInts(le) == 0 { pass = pass + 1 }

	// LcmInts with 0 → 0.
	var lf []int = new(3) []int{4, 0, 6}
	if math.LcmInts(lf) == 0 { pass = pass + 1 }

	// LcmInts cycle alignment example — common factors don't multiply.
	var lg []int = new(3) []int{4, 6, 8}
	if math.LcmInts(lg) == 24 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
