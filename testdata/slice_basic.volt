// v0.4 Phase 2: slice literal, indexing, len.
// nums[0] + nums[1] + nums[2] + nums[3] + len(nums) - 4 = 8 + 12 + 7 + 11 + 4 - 4 = 38
// Wait, recompute: 8+12+7+11=38, +len=4, total 42, -4 = 38. Let me adjust:
// We want exit 42, so sum 4 elements + len = 42. Pick {10, 9, 8, 11} → 38 + 4 = 42.

package main

fun main() int {
    var nums []int = []int{10, 9, 8, 11}
    ret nums[0] + nums[1] + nums[2] + nums[3] + len(nums)
}
