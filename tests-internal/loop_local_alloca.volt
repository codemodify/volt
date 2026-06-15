// Regression: locals declared INSIDE a loop body must not overflow the
// stack. LLVM frees alloca slots only at function return, never at block
// exit — so an alloca emitted in a loop body used to allocate a fresh
// slot every iteration, and a long loop segfaulted (SIGSEGV). Codegen now
// hoists every alloca to the entry block, so each slot is allocated once
// and reused.
//
// This loops 2,000,000 times with three heap/value locals per iteration
// (string + slice + struct ≈ 48 bytes of slots). If the allocas leaked,
// that's ~96 MB of stack growth → crash well past the 8 MB default. It
// completes in well under a second when the slots are reused correctly.

package main

type Pt struct {
	x int
	y int
}

fun main() int {
	var n int = 0
	var acc int = 0
	for n < 2000000 {
		var s string = "z"
		var buf []int = new(2) []int {}
		var p Pt = new Pt { x: n, y: n }
		buf[0] = p.x
		acc = acc + len(s) + buf[0] - p.y
		n = n + 1
	}
	// each iteration adds len("z")=1 + p.x - p.y (=0) → acc == 2000000
	if acc == 2000000 {
		ret 42
	}
	ret 0
}
