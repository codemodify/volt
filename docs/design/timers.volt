// volt:noformat — spec file; hand-aligned.
// =====================================================================
// timers.volt — time.Sleep and duration units
// =====================================================================
// `time.Sleep(ns int)` blocks the calling thread for at least n
// nanoseconds. The runtime lowers it to a `sys_nanosleep` syscall —
// no libc involved.
//
// The unit constants are compile-time integers in nanoseconds:
//
//   time.Nanosecond  ==           1
//   time.Microsecond ==       1_000
//   time.Millisecond ==   1_000_000
//   time.Second      == 1_000_000_000
//
// They expand inline; there's no `time.Second` storage at runtime.
//
//   volt run docs/design/timers.volt

package main

import (
    "log"
    "time"
)

fun main() {
    log.Println("sleeping 1ms...")
    time.Sleep(1 * time.Millisecond)
    log.Println("...1ms done")

    log.Println("sleeping 100μs...")
    time.Sleep(100 * time.Microsecond)
    log.Println("...100μs done")

    log.Println("timers ok")
}
