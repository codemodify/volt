// #7 stage 2 (runtime deadlock backstop): EXPECTED-RUNTIME-ABORT.
//
// A circular cross-thread deadlock: `worker` blocks reading `a` (which
// main never writes), and main blocks reading `b` (which the worker can
// only write AFTER its read of `a` returns). Neither can proceed. Both
// channels escape via `run`, so the compile-time static check (stage 1)
// cannot see the cycle — this is exactly what the runtime backstop is for.
//
// This program BUILDS fine and is EXPECTED to abort at runtime: once both
// threads are parked with no possible wake, the backstop prints
// "deadlock detected" and exits non-zero (rc=1) within ~1.25s — instead of
// hanging forever. It is NOT a normal rc=42 positive and NOT a build
// negative; the regression harness runs it expecting the clean abort.

package main

fun worker(a chan int, b chan int) {
	var v int = read(a)
	write(b, v)
}

fun main() int {
	var a chan int = new()
	var b chan int = new()
	run worker(a, b)
	var v int = read(b)
	ret v
}
