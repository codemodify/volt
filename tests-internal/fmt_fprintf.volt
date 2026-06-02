// fmt.Fprintf — formats into a string and writes through an io.Writer
// (vtable dispatch). Tested with both a local pointer-receiver type
// and os.File (value receiver via the _$iface trampoline).

package main

import "fmt"
import "io"
import "os"
import "log"

type Memo struct {
    buf string
}

fun (m *Memo) Write(s string) (int, error) {
    m.buf = m.buf + s
    ret len(s), nil
}

fun (m *Memo) Close() error { ret nil }

fun main() int {
    var pass int = 0

    // Case 1: pointer-receiver type through Fprintf.
    var m *Memo = new Memo {buf: ""}
    var n1 int = 0
    var e1 error = nil
    n1, e1 = fmt.Fprintf(m, "hello %s, n=%d\n", "world", 42)
    if e1 == nil {
        if n1 == 18 { pass = pass + 1 }
    }

    // Case 2: os.File via value-receiver _$iface trampoline.
    var path string = "/tmp/volt_fmt_fprintf_test.txt"
    f, oerr := os.Create(path)
    if oerr != nil {
        log.Println("create failed: %s", oerr.Error())
        ret 0
    }
    var n2 int = 0
    var e2 error = nil
    n2, e2 = fmt.Fprintf(f, "fd=%d bytes=%d\n", 1, 100)
    if e2 == nil {
        if n2 == 15 { pass = pass + 1 }
    }
    f.Close()

    log.Println("pass=%d/2", pass)
    if pass == 2 { ret 42 }
    ret 0
}
