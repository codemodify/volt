// Package syscall: PRIVILEGED — only runtime and stdlib should import.
//
// All functions here are COMPILER INTRINSICS. The codegen recognizes
// calls to them and lowers them directly to the runtime-provided
// symbols. Hence this file has no function bodies — its only role is
// to make `import "syscall"` resolve to a real package and give the
// type-checker visible signatures.
//
// File-I/O surface (added A.6):
//   Open(path, flags, mode) int          — returns fd or -errno
//   Close(fd) int                         — 0 or -errno
//   ReadAll(fd) string                    — reads to EOF; empty on err
//   WriteAll(fd, s) int                   — bytes written or -errno
//
// Open flag constants live in package `os` for user-facing use; the
// raw numeric flags are passed through.

package syscall

fun Write(fd int, s string) {}
fun Exit(code int) {}
fun Nanosleep(ns int) {}

fun Open(path string, flags int, mode int) int { ret 0 }
fun Close(fd int) int { ret 0 }
fun ReadAll(fd int) string { ret "" }
fun WriteAll(fd int, s string) int { ret 0 }

// TCP primitives. ip is a host-order IPv4 int (e.g. 127.0.0.1 →
// 0x7F000001). port and backlog are host-order ints. All return a
// non-negative fd / 0 on success, or -errno on failure.
fun TcpListen(ip int, port int, backlog int) int { ret 0 }
fun TcpAccept(lfd int) int { ret 0 }
fun TcpDial(ip int, port int) int { ret 0 }

// GetRandom returns up to n random bytes (n in [1, 256] recommended)
// via the Linux getrandom(2) syscall. The returned string contains
// the raw bytes; len(s) tells you how many bytes were actually
// produced (may be < n on a short read). Empty string on error.
fun GetRandom(n int) string { ret "" }

// Mkdir creates a directory at `path` with permission `mode` (POSIX
// bits; 0755 is the conventional default). Returns 0 on success or
// -errno.
fun Mkdir(path string, mode int) int { ret 0 }

// PathExists returns true iff `path` is accessible. Implemented via
// the faccessat(2) syscall with F_OK; doesn't follow / dereference,
// just checks the entry exists. Errors (including ENOENT) → false.
fun PathExists(path string) bool { ret false }

// Remove deletes the file or empty directory at `path`. Tries
// unlinkat without AT_REMOVEDIR first; on EISDIR retries with the
// directory flag. Returns 0 or -errno (most commonly -2 = ENOENT,
// -39 = ENOTEMPTY for non-empty dirs).
fun Remove(path string) int { ret 0 }

// BytesToString builds a fresh string from the first `n` bytes of
// `buf` (a []byte slice). The result owns its bytes — callers can
// keep mutating buf without aliasing the returned string. Used by
// bytes.Builder.String() to finalize an accumulator in O(n).
fun BytesToString(buf []byte, n int) string { ret "" }
