// Package syscall: PRIVILEGED — only runtime and stdlib should import.
//
// `Write(fd int, s string)`, `Exit(code int)`, and `Nanosleep(ns int)`
// are COMPILER INTRINSICS. The codegen recognizes calls to them and
// lowers them directly to the runtime-provided symbols. Hence this
// file has no function bodies — its only role is to make
// `import "syscall"` resolve to a real package.

package syscall
