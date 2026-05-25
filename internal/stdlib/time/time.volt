// Package time: minimal duration helpers.
//
// Sleep(ns int) blocks the calling goroutine for at least ns nanoseconds
// via the sys_nanosleep syscall (no libc).
//
// The duration unit identifiers (time.Nanosecond, time.Microsecond,
// time.Millisecond, time.Second) are compile-time integer constants
// expanded by the codegen — they have no storage in this module.
//
// time.After / time.Now are intentionally NOT in v0.5; add when an
// event-loop is introduced.

package time

import "syscall"

fun Sleep(ns int) {
    syscall.Nanosleep(ns)
}
