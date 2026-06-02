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
// appends bytes, Close is idempotent + auto-fires on Drop).
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
