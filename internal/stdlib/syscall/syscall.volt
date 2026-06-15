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

fun Write(fd int, s string) {
}

fun Exit(code int) {
}

fun Nanosleep(ns int) {
}

fun Open(path string, flags int, mode int) int {
	ret 0
}

fun Close(fd int) int {
	ret 0
}

fun ReadAll(fd int) string {
	ret ""
}

// ReadLine reads a single line from fd (up to, not including, the next
// '\n', or to EOF). On a terminal this returns the line the user typed
// when they press Enter — the primitive behind interactive prompts.
// Reads one byte at a time so it never consumes past the newline.
fun ReadLine(fd int) string {
	ret ""
}

fun WriteAll(fd int, s string) int {
	ret 0
}

// TCP primitives. ip is a host-order IPv4 int (e.g. 127.0.0.1 →
// 0x7F000001). port and backlog are host-order ints. All return a
// non-negative fd / 0 on success, or -errno on failure.
fun TcpListen(ip int, port int, backlog int) int {
	ret 0
}

fun TcpAccept(lfd int) int {
	ret 0
}

fun TcpDial(ip int, port int) int {
	ret 0
}

// GetRandom returns up to n random bytes (n in [1, 256] recommended)
// via the Linux getrandom(2) syscall. The returned string contains
// the raw bytes; len(s) tells you how many bytes were actually
// produced (may be < n on a short read). Empty string on error.
fun GetRandom(n int) string {
	ret ""
}

// Mkdir creates a directory at `path` with permission `mode` (POSIX
// bits; 0755 is the conventional default). Returns 0 on success or
// -errno.
fun Mkdir(path string, mode int) int {
	ret 0
}

// PathExists returns true iff `path` is accessible. Implemented via
// the faccessat(2) syscall with F_OK; doesn't follow / dereference,
// just checks the entry exists. Errors (including ENOENT) → false.
fun PathExists(path string) bool {
	ret false
}

// Remove deletes the file or empty directory at `path`. Tries
// unlinkat without AT_REMOVEDIR first; on EISDIR retries with the
// directory flag. Returns 0 or -errno (most commonly -2 = ENOENT,
// -39 = ENOTEMPTY for non-empty dirs).
fun Remove(path string) int {
	ret 0
}

// BytesToString builds a fresh string from the first `n` bytes of
// `buf` (a []byte slice). The result owns its bytes — callers can
// keep mutating buf without aliasing the returned string. Used by
// bytes.Builder.String() to finalize an accumulator in O(n).
fun BytesToString(buf []byte, n int) string {
	ret ""
}

// ProcWait reaps the child `pid` and returns its exit code (128+signal if
// killed; -1 on wait failure). Blocking. INTRINSIC → volt_exec_wait.
fun ProcWait(pid int) int {
	ret 0
}

// ProcSpawnFds forks+execs `path` (no shell), dup3'ing the child's
// stdin/stdout/stderr to inFd/outFd/errFd (pass -1 to inherit the parent's
// for that stream). No pipes, no pumping — the child does I/O directly on
// the fds. Returns the child pid, or -1 on failure. Backs exec.Cmd.Spawn
// (all -1) and SpawnWithStreams. INTRINSIC → volt_proc_spawn_fds.
fun ProcSpawnFds(path string, argv []string, env []string, dir string, inFd int, outFd int, errFd int) int {
	ret 0
}

// Kill sends signal `sig` to `pid` (15=SIGTERM, 9=SIGKILL); 0 on success,
// negative errno otherwise. INTRINSIC → volt_kill.
fun Kill(pid int, sig int) int {
	ret 0
}

// Getpid returns the caller's process id. INTRINSIC → volt_getpid.
fun Getpid() int {
	ret 0
}

// Gettid returns the caller's kernel thread id (unique per OS thread).
// INTRINSIC → volt_gettid.
fun Gettid() int {
	ret 0
}

// ReadSome does ONE read of up to `max` bytes from `fd`, returning what
// that read yielded ("" ⇒ EOF). The chunked counterpart to ReadAll, for
// streaming a pipe incrementally. INTRINSIC → volt_read_some.
fun ReadSome(fd int, max int) string {
	ret ""
}

// Terminal control (back the `term` stdlib package). All COMPILER
// INTRINSICS lowered to the runtime's ioctl/read/ppoll wrappers.
//   TermSize(fd)    — TIOCGWINSZ; packed (rows<<16)|cols, 0 on failure.
//   TermMakeRaw(fd) — enter cbreak mode (ICANON/ECHO/ISIG off, VMIN=1);
//                     0 on success or -errno. Saves prior settings.
//   TermRestore(fd) — restore settings saved by the last TermMakeRaw;
//                     0 on success / no-op, or -errno.
//   ReadByte(fd)    — read one byte: 0..255, -1 on EOF, -2 on error.
//   PollIn(fd, ms)  — readable wait: 1 ready, 0 timeout, -1 error;
//                     ms < 0 blocks indefinitely.
fun TermSize(fd int) int {
	ret 0
}

fun TermMakeRaw(fd int) int {
	ret 0
}

fun TermRestore(fd int) int {
	ret 0
}

fun ReadByte(fd int) int {
	ret 0
}

fun PollIn(fd int, ms int) int {
	ret 0
}

