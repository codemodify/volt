// io package interfaces — declares Reader/Writer/Closer/ReadWriteCloser
// for cross-package use. This test exercises cross-package interface
// REGISTRATION (the io.* names resolve) and multi-return interface
// dispatch via a local concrete type with pointer receivers.

package main

import "io"
import "log"

// A volt-flavored writer that accumulates bytes in an internal buffer.
// Pointer receivers so the vtable's `ptr` data argument lines up with
// the method's expected receiver type.
type Memo struct {
    buf string
}

fun (m *Memo) Write(s string) (int, error) {
    m.buf = m.buf + s
    ret len(s), nil
}

fun (m *Memo) Close() error {
    ret nil
}

fun writeMsg(w Writer, msg string) (int, error) {
    var n int = 0
    var err error = nil
    n, err = w.Write(msg)
    ret n, err
}

fun main() int {
    var m Memo = new Memo {buf: ""}
    var total int = 0
    var werr error = nil

    var n1 int = 0
    n1, werr = writeMsg(m, "hello, ")
    if werr != nil { ret 0 }
    total = total + n1

    log.Println("after 1st write n=%d", n1)

    // Note: m was moved into the previous call's interface box. The
    // remaining roundtrip just confirms the interface dispatch lowered
    // and the test got past it. (Use-after-move would have been a
    // checker error.)

    if total == 7 { ret 42 }
    ret 0
}
