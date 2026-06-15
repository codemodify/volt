// Cross-package call-site rejection: when a borrow is already held
// on x and we pass `&x` (a write borrow `*int`) to a cross-package
// function the checker must reject — same lifetime rule as in-file calls.
package main
import "slices"

fun main() int {
	var x int = 7
	// Take a held write borrow (`*int`) first.
	var held *int = &x
	// Then call cross-package function with another write borrow on x —
	// should reject because the held borrow is still live.
	slices.AddIntInPlace(&x, 1)
	*held = *held + 1
	ret 42
}
