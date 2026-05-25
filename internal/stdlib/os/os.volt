// Package os: ergonomic process & OS-level surface (thin layer over syscall).
//
// Surface (today):
//   Exit(code int)   — terminate the process with `code` as the exit status
//
// `Exit` is a COMPILER INTRINSIC — see codegen. The body below is a
// stand-in that never runs; it exists only so that `import "os"`
// resolves and the signature is visible to the type-checker.
//
// As volt grows, `os` is where higher-level wrappers will land:
// `os.Args`, `os.Getenv`, `os.Open`, `os.Hostname`, signals — each
// layered on top of `syscall` primitives. User code should prefer `os`
// over `syscall` whenever an `os` wrapper exists.

package os

import "syscall"

fun Exit(code int) {
    syscall.Exit(code)
}
