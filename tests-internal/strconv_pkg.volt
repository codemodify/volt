// strconv: Atoi (parse signed decimal) and Itoa (build decimal string).
// Also exercises string equality `==` / `!=` on %string operands.

package main

import "log"
import "strconv"

fun main() int {
    var pass int = 0

    var a string = strconv.Itoa(0)
    if a == "0" { pass = pass + 1 }
    var b string = strconv.Itoa(42)
    if b == "42" { pass = pass + 1 }
    var c string = strconv.Itoa(-123)
    if c == "-123" { pass = pass + 1 }
    var d string = strconv.Itoa(1000000)
    if d == "1000000" { pass = pass + 1 }

    v1, e1 := strconv.Atoi("42")
    if e1 == nil { if v1 == 42 { pass = pass + 1 } }
    v2, e2 := strconv.Atoi("-123")
    if e2 == nil { if v2 == -123 { pass = pass + 1 } }
    _v3, e3 := strconv.Atoi("")
    if e3 != nil { pass = pass + 1 }
    _v4, e4 := strconv.Atoi("not-a-number")
    if e4 != nil { pass = pass + 1 }

    var r string = strconv.Itoa(987654)
    vr, er := strconv.Atoi(r)
    if er == nil { if vr == 987654 { pass = pass + 1 } }

    log.Println("a=%s b=%s c=%s d=%s pass=%d/9", a, b, c, d, pass)
    if pass == 9 { ret 42 }
    ret 0
}
