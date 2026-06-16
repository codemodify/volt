// Package os: ergonomic process & OS-level surface (thin layer over syscall).
//
// Surface today:
//   Exit(code int)                       — terminate the process
//   Open(name) (File, error)             — open file for reading
//   Create(name) (File, error)           — create/truncate file for writing
//   (f File).Read() (string, error)      — read all remaining bytes
//   (f File).Write(s) (int, error)       — write s; bytes written or err
//   (f File).Close() error               — explicit early close
//   (f File).Drop()                      — auto-close at scope end
//
// `Exit` is a COMPILER INTRINSIC (same volt_exit stub as syscall.Exit).
// `File` is a regular volt struct passed by value at the API surface. The
// fd auto-closes at scope end (Drop). Close/Drop are POINTER-receiver
// methods, so the `closed` flag persists on your variable: an explicit
// Close is idempotent, and the scope-end Drop becomes a no-op once you've
// closed it — no double-close.

package os

import (
	"syscall"
	"errors"
	"bytes"
)

type File struct {
	fd     int
	closed bool
	pinned bool  // when true, Drop/Close don't call syscall.Close (stdin/stdout/stderr)
}

fun (f *File) Drop() {
	if f.closed {
		ret
	}
	if f.pinned {
		f.closed = true
		ret
	}
	syscall.Close(f.fd)
	f.closed = true
}

fun (f *File) Close() error {
	if f.closed {
		ret nil
	}
	if f.pinned {
		f.closed = true
		ret nil
	}
	var rc int = syscall.Close(f.fd)
	f.closed = true
	if rc < 0 {
		ret errors.New("close failed")
	}
	ret nil
}

fun (f File) Read() (string, error) {
	if f.closed {
		ret "", errors.New("file already closed")
	}
	var s string = syscall.ReadAll(f.fd)
	ret s, nil
}

fun (f File) Write(s string) (int, error) {
	if f.closed {
		ret 0, errors.New("file already closed")
	}
	var n int = syscall.WriteAll(f.fd, s)
	if n < 0 {
		ret 0, errors.New("write failed")
	}
	ret n, nil
}

// ReadSome reads up to `max` bytes in a single read and returns whatever
// was available — the chunked counterpart to Read (which drains to EOF).
// An empty result means EOF (or the file is closed). For streaming a pipe
// incrementally (e.g. an exec child's stdout) without blocking until the
// far end closes.
fun (f File) ReadSome(max int) string {
	if f.closed {
		ret ""
	}
	ret syscall.ReadSome(f.fd, max)
}

// Fd returns the underlying file descriptor — e.g. to hand a File's fd to
// exec.Cmd.SpawnWithStreams for OS-level stdio redirection.
fun (f File) Fd() int {
	ret f.fd
}

// NewFile wraps an already-open file descriptor as a File so its
// Read/ReadSome/Write/Close methods can drive it. Used to expose pipe
// ends (e.g. a child process's stdin/stdout/stderr). The File is unpinned, so
// Close / Drop will close the fd.
fun NewFile(fd int) File {
	ret new File {fd: fd, closed: false, pinned: false}
}

fun Open(name string) (File, error) {
	// O_RDONLY = 0
	var fd int = syscall.Open(name, 0, 0)
	if fd < 0 {
		ret new File {fd: -1, closed: true, pinned: false}, errors.New("open failed")
	}
	ret new File {fd: fd, closed: false, pinned: false}, nil
}

fun Create(name string) (File, error) {
	// O_WRONLY | O_CREAT | O_TRUNC = 1 | 0x40 | 0x200 = 577
	var fd int = syscall.Open(name, 577, 0644)
	if fd < 0 {
		ret new File {fd: -1, closed: true, pinned: false}, errors.New("create failed")
	}
	ret new File {fd: fd, closed: false, pinned: false}, nil
}

// Stdin returns a File wrapping fd 0 — the standard-input handle.
// Drop / Close are no-ops (the fd is pinned for the process lifetime).
fun Stdin() File {
	ret new File {fd: 0, closed: false, pinned: true}
}

// ReadLine reads one line from standard input (without the trailing
// newline). Blocks until the user presses Enter (on a terminal) or
// stdin reaches EOF. The building block for interactive prompts.
fun ReadLine() string {
	ret syscall.ReadLine(0)
}

// Stdout returns a File wrapping fd 1 — the standard-output handle.
// Drop / Close are no-ops (the fd is pinned for the process lifetime).
fun Stdout() File {
	ret new File {fd: 1, closed: false, pinned: true}
}

// Stderr returns a File wrapping fd 2 — the standard-error handle.
fun Stderr() File {
	ret new File {fd: 2, closed: false, pinned: true}
}

fun Exit(code int) {
	syscall.Exit(code)
}

// Argc returns the number of command-line arguments (including argv[0],
// the program name). Captured at process entry by _start.
fun Argc() int {
	ret 0
}

// ArgAt returns the i-th argument as a string. Out-of-range returns "".
// argv[0] is the program name. Bytes live for the process lifetime.
fun ArgAt(i int) string {
	ret ""
}

// Getenv returns the value of the named environment variable, or ""
// when the variable is not set. Empty string indistinguishable from
// "unset"; if you need to tell them apart, use a future LookupEnv.
fun Getenv(name string) string {
	ret ""
}

// GetenvOr returns the value of the named environment variable, or
// `defaultValue` if the variable is unset *or* set to the empty
// string. Ergonomic for config reads like `port := os.GetenvOr(
// "PORT", "8080")`. The unset-vs-empty conflation matches Getenv's
// documented semantics; callers that need to tell them apart should
// use a future LookupEnv.
fun GetenvOr(name string, defaultValue string) string {
	var v string = Getenv(name)
	if v == "" {
		ret defaultValue
	}
	ret v
}

// Args is a convenience that builds []string from Argc + ArgAt.
fun Args() []string {
	var (
		n   int      = Argc()
		out []string = new(n) []string {}
	)
	for i := 0; i < n; i = i + 1 {
		out[i] = ArgAt(i)
	}
	ret out
}

// Mkdir creates a directory at `path` with POSIX permission `mode`
// (e.g. 493 = 0o755). Returns the raw syscall result — 0 on success,
// -errno on failure (most commonly -17 = EEXIST).
fun Mkdir(path string, mode int) int {
	ret syscall.Mkdir(path, mode)
}

// MkdirAll creates `path` along with any necessary parents,
// applying `mode` to each newly-created directory. Existing
// directories along the way are not modified. A pre-existing
// `path` returns 0 (no work). Returns 0 on success or the raw
// syscall result of the first non-recoverable Mkdir failure;
// EEXIST (-17) is silently absorbed since it just means a parent
// was created concurrently or pre-exists. Mirrors Go's
// os.MkdirAll for the common parent-directory-creation idiom.
fun MkdirAll(path string, mode int) int {
	var n int = len(path)
	if n == 0 {
		ret 0
	}
	var end int = n
	for end > 1 {
		if path[end - 1] != 47 {
			break
		}
		end = end - 1
	}
	if Exists(path) {
		ret 0
	}
	for i := 1; i <= end; i = i + 1 {
		var isSlash bool = false
		if i == end {
			isSlash = true
		} else {

			if path[i] == 47 {
				isSlash = true
			}
		}
		if !isSlash {
			continue
		}
		var b bytes.Builder = new bytes.Builder{}
		for j := 0; j < i; j = j + 1 {
			b.WriteByte(path[j])
		}
		var prefix string = b.String()
		if len(prefix) == 0 {
			continue
		}
		if Exists(prefix) {
			continue
		}
		var r int = Mkdir(prefix, mode)
		if r != 0 {
			if r != -17 {
				ret r
			}
		}
	}
	ret 0
}

// Exists reports whether `path` is reachable on disk. Backed by the
// faccessat(2) syscall with F_OK; symlinks are followed.
fun Exists(path string) bool {
	ret syscall.PathExists(path)
}

// Remove deletes the file or empty directory at `path`. Mirrors Go's
// os.Remove. Returns 0 on success or -errno; common errors are -2
// (ENOENT) and -39 (ENOTEMPTY for non-empty directories).
fun Remove(path string) int {
	ret syscall.Remove(path)
}

// ReadFile reads the entire named file and returns its contents.
// Convenience over Open + Read + Close — closes the file in all
// paths, including when ReadAll itself errors.
fun ReadFile(name string) (string, error) {
	var (
		f   File  = new File {}
		err error = nil
	)
	f, err = Open(name)
	if err != nil {
		ret "", err
	}
	var data string = ""
	data, err = f.Read()
	f.Close()
	if err != nil {
		ret "", err
	}
	ret data, nil
}

// WriteFile creates (or truncates) `name` and writes `data` to it.
// Permission `mode` is applied at creation; 0644 (= 420 decimal) is
// the conventional default for plain files. Returns 0 on success or
// -errno propagated from the underlying syscall.
fun WriteFile(name string, data string, mode int) error {
	var fd int = syscall.Open(name, 577, mode)  // O_WRONLY|O_CREAT|O_TRUNC = 577
	if fd < 0 {
		ret errors.New("WriteFile: open failed")
	}
	var n int = syscall.WriteAll(fd, data)
	syscall.Close(fd)
	if n < 0 {
		ret errors.New("WriteFile: write failed")
	}
	ret nil
}

// AppendFile appends `data` to `name`, creating the file with
// permission `mode` if it doesn't already exist. Unlike WriteFile
// (which truncates), AppendFile preserves existing contents and
// adds at the end. Opens with O_WRONLY | O_CREAT | O_APPEND = 1089.
// Useful for log writers, audit trails, and accumulating-output
// patterns where each call extends the file.
fun AppendFile(name string, data string, mode int) error {
	// O_WRONLY (1) | O_CREAT (0o100=64) | O_APPEND (0o2000=1024) = 1089
	var fd int = syscall.Open(name, 1089, mode)
	if fd < 0 {
		ret errors.New("AppendFile: open failed")
	}
	var n int = syscall.WriteAll(fd, data)
	syscall.Close(fd)
	if n < 0 {
		ret errors.New("AppendFile: write failed")
	}
	ret nil
}

// UserHomeDir returns the current user's home directory by reading
// the $HOME environment variable. Mirrors Go's os.UserHomeDir for
// the Unix case (Windows / Plan 9 variants aren't applicable — volt
// is Linux-only in v1). Returns ("", error) if $HOME is unset or
// empty.
fun UserHomeDir() (string, error) {
	var h string = Getenv("HOME")
	if len(h) == 0 {
		ret "", errors.New("os: $HOME not defined")
	}
	ret h, nil
}

// UserConfigDir returns the default root directory for user-specific
// configuration data — `$XDG_CONFIG_HOME` if set, else `$HOME/.config`.
// Mirrors Go's os.UserConfigDir for the Linux case. Returns ("", error)
// if neither variable is usable.
fun UserConfigDir() (string, error) {
	var xdg string = Getenv("XDG_CONFIG_HOME")
	if len(xdg) > 0 {
		ret xdg, nil
	}
	var h string = Getenv("HOME")
	if len(h) == 0 {
		ret "", errors.New("os: neither $XDG_CONFIG_HOME nor $HOME defined")
	}
	ret h + "/.config", nil
}

// UserCacheDir returns the default root directory for user-specific
// cache data — `$XDG_CACHE_HOME` if set, else `$HOME/.cache`. Mirrors
// Go's os.UserCacheDir for the Linux case. Returns ("", error) if
// neither variable is usable. Useful for ephemeral storage that
// callers want isolated from durable config (UserConfigDir).
fun UserCacheDir() (string, error) {
	var xdg string = Getenv("XDG_CACHE_HOME")
	if len(xdg) > 0 {
		ret xdg, nil
	}
	var h string = Getenv("HOME")
	if len(h) == 0 {
		ret "", errors.New("os: neither $XDG_CACHE_HOME nor $HOME defined")
	}
	ret h + "/.cache", nil
}

// TempDir returns the default directory for temporary files —
// `$TMPDIR` if set, else `/tmp` (Linux convention). Mirrors Go's
// os.TempDir for Unix. Always returns a non-empty path.
fun TempDir() string {
	var t string = Getenv("TMPDIR")
	if len(t) > 0 {
		ret t
	}
	ret "/tmp"
}

// Process execution moved to the `exec` package (a port of Go's
// os/exec): exec.Command(name, args) runs a program WITHOUT a shell
// (no injection), exec.Shell(line) is the explicit /bin/sh -c escape
// hatch, and *Cmd offers Run / Output / CombinedOutput. The old
// os.Run / os.Ok / os.Output shell shims were removed in favor of it.
