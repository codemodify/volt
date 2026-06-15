// EXEC.caller-leaks (part 1): `a, b = f()` must free the OLD heap value of
// each LHS slot before overwriting it — the multi-assign path previously
// skipped the A3 reassignment cleanup that single-assign already does, so
// reassigning a heap-valued var via multi-assign leaked it every time.
//
// Here `s` holds a fresh heap concat each iteration, then is multi-assigned
// from pair(); the old heap string must be freed at the multi-assign. The
// loop runs enough times that a double-free (the failure mode if the
// cleanup freed a borrowed/aliased value) would crash, and a leak would
// show as VmPeak growth (verified separately ~flat at 84 kB over 3M iters).

package main

fun pair() (string, int) { ret "", 0 }

fun main() int {
	var s string = ""
	var x int = 0
	var acc int = 0
	var k int = 0
	for k < 200000 {
		s = "aaaaaaaa" + "bbbbbbbb" // heap concat → registers a string drop on s
		acc = acc + len(s)          // read s
		s, x = pair()               // multi-assign: frees old heap s, stores ""
		k = k + 1
	}
	// 200000 * len("aaaaaaaabbbbbbbb")=16 → 3,200,000; x stays 0
	if x == 0 && acc == 3200000 {
		ret 42
	}
	ret 0
}
