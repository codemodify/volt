// A3 sub-scope drops: slice/map vars declared inside a loop body
// must auto-free at the END OF EACH ITERATION, not at function end.
// Without per-iter freeing, the freelist would never recycle and a
// long-running tight loop would balloon the heap. The drop entries
// already record c.scopeDepth at registration, so the existing
// popScope/emitDropsAbove machinery should handle this — this test
// proves the slice/map kinds participate correctly.
package main
import "log"

fun work() int {
	var sum int = 0
	// 10000 iterations × 100-int slice = ~8MB peak if NOT freed; with
	// per-iter free we stay within the bump-arena recycling and never
	// hit OOM. The check is that the program completes within sane
	// memory bounds; we use a large iteration count to make a leak
	// observable as a crash on memory pressure.
	for i := 0; i < 10000; i++ {
		var s []int = new(100) []int {}
		s[0] = i
		s[99] = i
		sum = sum + s[0] + s[99]
	}
	ret sum
}

fun mapWork() int {
	var total int = 0
	for i := 0; i < 5000; i++ {
		var m map[string]int = new()
		m["x"] = i
		m["y"] = i * 2
		total = total + m["x"] + m["y"]
	}
	ret total
}

fun nestedScopes() int {
	var keep int = 0
	for i := 0; i < 100; i++ {
		if i % 2 == 0 {
			var inner []int = new(50) []int {}
			inner[0] = i
			keep = keep + inner[0]
		} else {
			var other []int = new(75) []int {}
			other[0] = i * 2
			keep = keep + other[0]
		}
	}
	ret keep
}

fun main() int {
	var a int = work()
	// sum = sum over i=0..9999 of (i + i) = 2 * (0+1+...+9999) = 2*49995000 = 99990000
	if a != 99990000 { ret 1 }

	var b int = mapWork()
	// total = sum over i=0..4999 of (i + 2i) = 3 * sum(0..4999) = 3*12497500 = 37492500
	if b != 37492500 { ret 2 }

	var c int = nestedScopes()
	// keep: for even i (0..98 step 2, 50 vals): inner[0]=i, sum=0+2+...+98 = 2450
	// for odd i (1..99 step 2, 50 vals): other[0]=i*2, sum=2+6+...+198 = 50*100 = 5000
	// total = 2450 + 5000 = 7450
	if c != 7450 { ret 3 }

	log.Println("a=%d b=%d c=%d", a, b, c)
	ret 42
}
