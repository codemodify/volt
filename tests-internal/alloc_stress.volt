// alloc_stress — verifies the allocator survives well past the old
// 16 MB BSS cap. 100 000 slice allocations × ~80 bytes each = ~8 MB
// before counting arena overhead. With the BSS bump, this used to
// volt_die() somewhere around iteration 200 k; with the mmap-backed
// freelist allocator, it just keeps growing arena chunks via mmap.
//
// (Drops don't yet free per-iteration since slice Drop isn't wired —
// see TODO. But the allocator no longer hard-caps at 16 MB.)

package main

fun main() int {
    for i := 0; i < 100000; i++ {
        var _s []int = new []int{0, 0, 0, 0, 0, 0, 0, 0}
    }
    ret 42
}
