// Package bufio: buffered I/O.
//
// v1 scope: a single Buffer type that accumulates string chunks in
// memory and flushes them to a caller-supplied writer function.
//
// The "writer function" is a `fun(string) (int, error)` value (not
// an io.Writer interface) — function values are simpler than method
// dispatch on a struct's interface field, and adequate for the
// common case (callers pass `f.Write` or any matching closure).
//
// Future widening: when method-on-field-receiver dispatch lands,
// the writer slot can become a real `io.Writer` interface value.

package bufio

import "bytes"
import "strconv"

type Buffer struct {
    write fun(string) (int, error)
    buf   string
}

fun New(write fun(string) (int, error)) *Buffer {
    var b *Buffer = new Buffer {write: write, buf: ""}
    ret b
}

fun (b *Buffer) WriteString(s string) {
    b.buf = b.buf + s
}

// WriteByte appends a single byte to the buffer. Builder-style
// counterpart to WriteString.
fun (b *Buffer) WriteByte(c byte) {
    b.buf = b.buf + chr(c)
}

// WriteInt appends the decimal representation of n. Delegates to
// strconv.Itoa. Useful for assembling formatted lines without
// pre-computing the int's string form.
fun (b *Buffer) WriteInt(n int) {
    b.buf = b.buf + strconv.Itoa(n)
}

// WriteBool appends "true" or "false" depending on v.
fun (b *Buffer) WriteBool(v bool) {
    if v { b.buf = b.buf + "true"; ret }
    b.buf = b.buf + "false"
}

// Len returns the current number of buffered bytes (those that have
// been written but not yet flushed). Useful for size-based flush
// triggers (e.g. flush when Len() >= 4096).
fun (b *Buffer) Len() int {
    ret len(b.buf)
}

// Reset discards the buffer contents without writing anything to
// the underlying writer. The next Flush is a no-op until more is
// written. Useful when the caller wants to abandon an in-flight
// buffered payload (e.g. on validation failure mid-build).
fun (b *Buffer) Reset() {
    b.buf = ""
}

// String returns the current buffered contents WITHOUT flushing.
// Reads the staged payload — useful for inspection / logging /
// validation before committing via Flush.
fun (b *Buffer) String() string {
    ret b.buf
}

// Flush writes the accumulated buffer to the underlying writer
// function. After a successful flush the buffer is reset.
fun (b *Buffer) Flush() (int, error) {
    if len(b.buf) == 0 { ret 0, nil }
    var payload string = b.buf
    b.buf = ""
    var n int = 0
    var err error = nil
    n, err = b.write(payload)
    ret n, err
}

// SplitLines splits s into lines on `\n` boundaries. A trailing
// `\r` (CRLF line ending) on each piece is stripped. The terminating
// `\n` is NOT included. Empty input returns an empty slice. A
// trailing `\n` produces a trailing empty piece (matches `read
// then split` semantics).
fun SplitLines(s string) []string {
    var n int = len(s)
    var out []string = new(0) []string {}
    if n == 0 { ret out }
    var start int = 0
    for i := 0; i < n; i++ {
        if s[i] == 10 {                       // '\n'
            var end int = i
            if end > start {
                if s[end - 1] == 13 { end = end - 1 }   // strip '\r'
            }
            var b *bytes.Builder = bytes.NewBuilder()
            for k := start; k < end; k++ {
                b.WriteByte(s[k])
            }
            out = append(out, b.String())
            start = i + 1
        }
    }
    if start < n {
        var end int = n
        if s[end - 1] == 13 { end = end - 1 }
        var b *bytes.Builder = bytes.NewBuilder()
        for k := start; k < end; k++ {
            b.WriteByte(s[k])
        }
        out = append(out, b.String())
    }
    ret out
}
