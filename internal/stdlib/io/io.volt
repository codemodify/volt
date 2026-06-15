// Package io: minimal interfaces for byte-stream I/O.
//
// Surface (volt-flavored — string-oriented, since strings are volt's
// natural immutable byte sequence):
//
//   Reader interface           — Read() (string, error)
//   Writer interface           — Write(s string) (int, error)
//   Closer interface           — Close() error
//   ReadWriteCloser interface  — all of the above
//
// `os.File` satisfies all four (Read = ReadAll under the hood, Write
// appends bytes, Close auto-fires at scope end via Drop). Call explicit
// Close at most once — its value receiver means the `closed` flag doesn't
// persist, so a second Close re-closes the fd rather than being a no-op.
//
// Future widening: a Go-style `Read(p []byte) (int, error)` that fills
// a caller-provided buffer; needs slice-element-write support across
// FFI boundaries, deferred.

package io

type Reader interface {
    Read() (string, error)
}

type Writer interface {
    Write(s string) (int, error)
}

type Closer interface {
    Close() error
}

type ReadWriteCloser interface {
    Read() (string, error)
    Write(s string) (int, error)
    Close() error
}

// Copy reads everything from src and writes it to dst, returning the
// number of bytes written and any error encountered. A read error
// short-circuits the write (returns (0, readErr)). A write error
// returns (n, writeErr) where n is whatever Write reported. In the
// volt I/O model Read returns the full content in one shot (no
// chunking), so Copy is effectively `s := src.Read(); dst.Write(s)`
// with error plumbing — useful as a one-line "drain src into dst"
// idiom matching Go's surface.
fun Copy(dst Writer, src Reader) (int, error) {
    var s string = ""
    var rerr error = nil
    s, rerr = src.Read()
    if rerr != nil { ret 0, rerr }
    var n int = 0
    var werr error = nil
    n, werr = dst.Write(s)
    ret n, werr
}

// StringReader is an in-memory io.Reader over a fixed string — the one
// concrete reader the stdlib provides (volt's type namespace is global,
// so packages can't each define their own `Reader`; that name is the
// interface above). strings.NewReader / bytes.NewReader return one of
// these. Read is one-shot: the FIRST call returns the whole content (to
// EOF), every later call returns "" (EOF) — a proper mutable cursor,
// matching os.File. The pointer receiver carries that mutable state
// across an io.Reader interface boxing.
type StringReader struct {
    s    string
    done bool
}

// NewStringReader wraps s as an io.Reader.
fun NewStringReader(s string) *StringReader {
    ret new StringReader { s: "" + s, done: false }
}

fun (r *StringReader) Read() (string, error) {
    if r.done {
        ret "", nil
    }
    r.done = true
    ret "" + r.s, nil
}

// StringWriter is an in-memory io.Writer that accumulates everything
// written into a string, read back via String(). It's the io-package's
// in-memory output sink — collect io.Copy / exec.Cmd.Start output in
// memory, then read it. A `*StringWriter` boxed into io.Writer shares its
// state (pointer-receiver Write), so writes through the box persist.
// (bytes.Builder also satisfies io.Writer; StringWriter is the dependency-
// free option for the io package itself, which can't import bytes.)
type StringWriter struct {
    buf string
}

// NewStringWriter returns an empty *StringWriter ready to collect writes.
fun NewStringWriter() *StringWriter {
    ret new StringWriter { buf: "" }
}

fun (w *StringWriter) Write(s string) (int, error) {
    w.buf = w.buf + s
    ret len(s), nil
}

// String returns everything written so far.
fun (w *StringWriter) String() string {
    ret "" + w.buf
}
