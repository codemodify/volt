// Package syscall: PRIVILEGED — only runtime and stdlib should import.
//
// `Write(fd int, s string)` and `Exit(code int)` are COMPILER INTRINSICS
// in v0.3. The codegen recognizes calls to them and lowers them directly
// to the runtime-provided `crgz_write` / `crgz_exit` symbols.  Hence
// this file has no function bodies — its only role is to make
// `import "syscall"` resolve to a real package.

package syscall
