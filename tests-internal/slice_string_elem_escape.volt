// S1 soundness: extracting an owned element and letting it ESCAPE the slice's
// lifetime must not use-after-free. Two routes:
//  (a) index-binding `x := xs[i]` deep-copies (S1a) → x independent → safe to
//      return even after the slice's backing is freed.
//  (b) range/inline element reads alias, so the compiler PINS such slices
//      (their element payloads are NOT freed) → the aliased value stays valid.
// Either way: no UAF.
package main

fun viaBinding() string {
	var xs []string = new(2) []string {"foo", "barbar"}
	var x string = xs[0] // deep-copied; xs freed at scope end
	ret x
}

fun viaRange() string {
	var xs []string = new(2) []string {}
	xs[0] = "aa" + "bb"
	xs[1] = "cc" + "dd"
	for i, v := range xs {
		if i == 0 {
			ret v // v aliases xs[0]; xs is PINNED → element payload survives
		}
	}
	ret "z"
}

fun main() int {
	var a string = viaBinding() // "foo" → 3
	var b string = viaRange()   // "aabb" → 4
	if len(a) == 3 && len(b) == 4 {
		ret 42
	}
	ret 0
}
