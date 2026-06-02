package main

import "io"
import "log"
import "errors"

// Source — a Reader that returns a fixed string. Pointer receivers
// so the interface vtable's ptr data argument lines up.
type Source struct {
    msg string
}

fun (s *Source) Read() (string, error) {
    ret s.msg, nil
}

// FailSource — a Reader that always errors.
type FailSource struct {
    pad int
}

fun (s *FailSource) Read() (string, error) {
    ret "", errors.New("source failure")
}

// Sink — a Writer that accumulates into an internal buffer.
type Sink struct {
    buf string
}

fun (m *Sink) Write(s string) (int, error) {
    m.buf = m.buf + s
    ret len(s), nil
}

fun main() int {
    var pass int = 0

    // Copy — happy path. Source has 11 bytes; Sink should receive them.
    var src1 Source = new Source { msg: "hello world" }
    var dst1 Sink = new Sink { buf: "" }
    var n1 int = 0
    var err1 error = nil
    n1, err1 = io.Copy(dst1, src1)
    if err1 == nil { pass = pass + 1 }
    if n1 == 11 { pass = pass + 1 }

    // Copy — empty source.
    var src2 Source = new Source { msg: "" }
    var dst2 Sink = new Sink { buf: "" }
    var n2 int = 0
    var err2 error = nil
    n2, err2 = io.Copy(dst2, src2)
    if err2 == nil { pass = pass + 1 }
    if n2 == 0 { pass = pass + 1 }

    // Copy — read error short-circuits.
    var src3 FailSource = new FailSource { pad: 0 }
    var dst3 Sink = new Sink { buf: "" }
    var n3 int = 0
    var err3 error = nil
    n3, err3 = io.Copy(dst3, src3)
    if err3 != nil { pass = pass + 1 }
    if n3 == 0 { pass = pass + 1 }

    // Copy — larger payload.
    var src4 Source = new Source { msg: "the quick brown fox jumps over the lazy dog" }
    var dst4 Sink = new Sink { buf: "" }
    var n4 int = 0
    var err4 error = nil
    n4, err4 = io.Copy(dst4, src4)
    if err4 == nil { pass = pass + 1 }
    if n4 == 43 { pass = pass + 1 }

    log.Println("pass=%d", pass)
    if pass == 8 { ret 42 }
    ret 0
}
