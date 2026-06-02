// runtime.AllocCount / FreeCount / LiveBytes smoke test. These
// are the load-bearing accessors for memory profiling — snapshot
// before/after a workload and compare deltas to find alloc hotspots
// or leaks. All three are monotonically related: AllocCount >=
// FreeCount, and LiveBytes is approximately (sum of allocated
// slot sizes) - (sum of freed slot sizes).
package main
import "log"
import "runtime"

fun main() int {
	// Baseline snapshot — note that startup + main prelude already
	// did some allocs, so we work in deltas, not absolute values.
	var ac0 int = runtime.AllocCount()
	var fc0 int = runtime.FreeCount()
	var lb0 int = runtime.LiveBytes()

	// Allocate a known shape and verify deltas move monotonically.
	var s []int = new(100) []int {}
	for i := 0; i < 100; i++ { s[i] = i }
	var sum int = 0
	for i := 0; i < 100; i++ { sum = sum + s[i] }
	if sum != 4950 { ret 1 }

	var ac1 int = runtime.AllocCount()
	var lb1 int = runtime.LiveBytes()
	if ac1 <= ac0 { ret 2 }    // we allocated something
	if lb1 <= lb0 { ret 3 }    // live bytes grew

	// Sanity: FreeCount monotonic.
	var fc1 int = runtime.FreeCount()
	if fc1 < fc0 { ret 4 }

	// After Drop the live bytes should drop back (auto-free on
	// scope exit). We can't observe it before the implicit drop
	// because `s` is still in scope here — instead, run alloc/free
	// inside a sub-block.
	{
		var t []int = new(64) []int {}
		t[0] = 1
		if t[0] != 1 { ret 5 }
	}                            // t dropped here
	var lb2 int = runtime.LiveBytes()
	var fc2 int = runtime.FreeCount()
	if fc2 <= fc1 { ret 6 }    // at least one free happened
	if lb2 > lb1 { ret 7 }     // shouldn't have grown after a drop

	// Profile a no-alloc loop: deltas should be ~0 even across 1k iters.
	var ac2 int = runtime.AllocCount()
	var acc int = 0
	for i := 0; i < 1000; i++ { acc = acc + i }
	if acc != 499500 { ret 8 }
	var ac3 int = runtime.AllocCount()
	if ac3 != ac2 { ret 9 }    // arithmetic-only loop allocates nothing

	log.Println("alloc=%d free=%d live=%d", ac3, fc2, lb2)
	ret 42
}
