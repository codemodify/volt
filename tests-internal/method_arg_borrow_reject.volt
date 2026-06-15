// Method-argument borrow rejection (item 4): passing `&t` into a
// write-borrow (`*int`) parameter while t is already write-borrowed
// must be rejected — the method's parameter gets the same call-site
// lifetime check as a free-function argument.
package main

type Box struct {
	v int
}

fun (b &Box) addInto(dst *int) { *dst = *dst + b.v }

fun main() int {
	var bx Box = new Box {v: 5}
	var t int = 0
	var held *int = &t
	bx.addInto(&t)   // ERROR: t already write-borrowed by `held`
	*held = 1
	ret 0
}
