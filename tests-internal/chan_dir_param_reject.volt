package main

// Negative test: passing a `chan read T` argument to a `chan write T`
// parameter is incompatible — the directions can't reconcile. Previously
// this was only caught when the callee tried the disallowed op (a deferred
// error far from the call site); now surfaces at the call.
//
// Expected error: cannot pass `chan read T` to a `chan write T` parameter — directions are incompatible

fun sender(out chan write int) {
	write(out, 42)
}

fun main() int {
	var ch chan int = new(2)
	var r chan read int = ch
	run sender(r)
	ret 0
}
