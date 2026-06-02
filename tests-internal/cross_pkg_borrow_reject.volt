// Cross-package call-site rejection: when a borrow is already held
// on x and we pass `&mut x` (or `&x`) to a cross-package function
// the checker must reject — same lifetime rule as in-file calls.
package main
import "slices"

fun main() int {
	var x int = 7
	// Take a held &mut borrow first.
	var held &mut int = &mut x
	// Then call cross-package function with another &mut on x —
	// should reject because the held borrow is still live.
	slices.AddIntInPlace(&mut x, 1)
	*held = *held + 1
	ret 42
}
