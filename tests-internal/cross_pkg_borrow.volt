// Cross-package call-site borrow checks: when a function in another
// package takes `&mut T` / `&T`, the call-site borrow lifetime check
// fires the same way it does for in-file functions. The infra is
// already wired through `extPkgs` — this test exercises the path.
package main
import "log"
import "slices"

fun main() int {
	// Positive: two distinct &mut int sources are fine (they're not
	// the same variable, so no alias conflict).
	var x int = 7
	var y int = 11
	slices.Swap2Ints(&mut x, &mut y)
	if x != 11 { ret 1 }
	if y != 7 { ret 2 }

	// Positive: sequential &mut calls — each call's borrow lifetime
	// ends on return.
	var c int = 0
	slices.AddIntInPlace(&mut c, 3)
	slices.AddIntInPlace(&mut c, 5)
	slices.AddIntInPlace(&mut c, 4)
	if c != 12 { ret 3 }

	// Positive: bare-name passing (volt auto-infers &mut for `&mut T`
	// parameter shape) — identical behavior.
	var v int = 10
	slices.AddIntInPlace(v, 32)
	if v != 42 { ret 4 }

	// Positive: max/min in-place accumulators across a small fold.
	var mx int = -1
	var mn int = 9999
	var nums []int = new(5) []int {3, 1, 4, 1, 5}
	for i := 0; i < len(nums); i++ {
		slices.MaxAssignInt(&mut mx, nums[i])
		slices.MinAssignInt(&mut mn, nums[i])
	}
	if mx != 5 { ret 5 }
	if mn != 1 { ret 6 }

	log.Println("ok")
	ret 42
}
