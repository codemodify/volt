// S1b safety: a []string whose element ALIASES another owner's payload must
// NOT be element-freed (else double-free / use-after-free). The compiler
// PINS such a slice (its element payloads leak — safe — never freed twice).
// Vector: cross-slice element move `ys[i] = xs[j]` (the RHS element read is
// NOT deep-copied, so ys[i] aliases xs[j]). A double-free would crash; this
// returns 42.
package main

fun main() int {
	var xs []string = new(2) []string {}
	xs[0] = "aa" + "bb"
	xs[1] = "cc" + "dd"
	var ys []string = new(2) []string {}
	ys[0] = xs[0] // ys[0] aliases xs[0] → both xs and ys pinned (no elem-free)
	ys[1] = xs[1]
	if len(ys[0]) + len(xs[1]) == 8 {
		ret 42
	}
	ret 0
}
