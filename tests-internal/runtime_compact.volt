// runtime.Compact() smoke: allocate + free a mixed-size workload
// then call Compact() and verify the program continues to run
// correctly (allocations after compaction succeed). The actual
// merge effectiveness isn't directly observable from user code;
// we rely on the absence of crashes + post-compact allocations
// working as the integration signal.
package main
import "log"
import "runtime"

fun churn(n int) int {
	var sum int = 0
	for i := 0; i < n; i++ {
		var s []int = new(8) []int {}
		s[0] = i
		sum = sum + s[0]
	}
	ret sum
}

fun main() int {
	// Phase 1: produce lots of free blocks of various sizes via the
	// auto-free machinery on owned slices.
	var pre int = churn(1000)
	if pre != 499500 { ret 1 }

	// Phase 2: compact. Should be safe to call any time.
	runtime.Compact()

	// Phase 3: verify allocator still works post-compaction.
	var post int = churn(1000)
	if post != 499500 { ret 2 }

	// Multiple compact calls should be idempotent.
	runtime.Compact()
	runtime.Compact()
	runtime.Compact()

	var final int = churn(500)
	// sum 0..499 = 499*500/2 = 124750
	if final != 124750 { ret 3 }

	log.Println("ok")
	ret 42
}
