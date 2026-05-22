// Package runtime hosts the volt runtime that is linked into every binary.
//
// The runtime provides:
//   - _start entry point (assembly): bootstrap before user main
//   - Syscall stubs for Linux amd64 (write, exit, ...)
//   - Memory allocator (v0.2+)
//   - Goroutine scheduler (v0.2+)
//   - Channel implementation (v0.2+)
//   - Copying-stack growth (v1)
//
// The actual runtime artifacts live in the asm/ subdirectory (a
// non-Go-package directory, so `go build` doesn't try to compile them).
// This Go file embeds them so the compiler binary is self-contained.
package runtime

import _ "embed"

//go:embed asm/start_amd64.s
var StartAmd64Asm []byte

//go:embed asm/runtime.c
var RuntimeC []byte
