// String concatenation: `a + b` for two %string operands → fresh heap
// %string. Also tests the chr(b) builtin (1-byte string from byte).
//
// Foundation for fmt.Sprintf, strconv.Itoa, strings.Replace, etc. —
// any operation that builds a new string from pieces.

package main

import "log"

fun main() int {
    var pass int = 0

    var a string = "hello"
    var b string = ", world"
    var c string = a + b
    if len(c) == 12 { pass = pass + 1 }

    // Literal + literal
    var d string = "foo" + "bar"
    if len(d) == 6 { pass = pass + 1 }

    // Chain of three
    var e string = d + "baz"
    if len(e) == 9 { pass = pass + 1 }

    // chr(b) — byte to 1-char string
    var f string = chr(65) + chr(66) + chr(67)
    if len(f) == 3 { pass = pass + 1 }
    if f[0] == 65 { pass = pass + 1 }

    // Empty + non-empty
    var g string = "" + "tail"
    if len(g) == 4 { pass = pass + 1 }

    log.Println("c=%s e=%s f=%s pass=%d/6", c, e, f, pass)
    if pass == 6 { ret 42 }
    ret 0
}
