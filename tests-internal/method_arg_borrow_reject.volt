// Method-argument borrow rejection (item 4): passing `&mut t` to a
// method while t is already mutably borrowed must be rejected — the
// method's parameter gets the same call-site lifetime check as a
// free-function argument.
package main

type Box struct {
	v int
}

fun (b &Box) addInto(dst &mut int) { *dst = *dst + b.v }

fun main() int {
	var bx Box = new Box {v: 5}
	var t int = 0
	var held &mut int = &mut t
	bx.addInto(&mut t)   // ERROR: t already mutably borrowed
	*held = 1
	ret 0
}
