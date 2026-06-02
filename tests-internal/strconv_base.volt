// strconv.ParseInt / FormatInt — arbitrary-base integer conversion.

package main

import "strconv"
import "log"

fun main() int {
    var pass int = 0

    // FormatInt — base 2
    if strconv.FormatInt(0, 2) == "0" { pass = pass + 1 }
    if strconv.FormatInt(5, 2) == "101" { pass = pass + 1 }
    if strconv.FormatInt(255, 2) == "11111111" { pass = pass + 1 }

    // FormatInt — base 16
    if strconv.FormatInt(255, 16) == "ff" { pass = pass + 1 }
    if strconv.FormatInt(4096, 16) == "1000" { pass = pass + 1 }
    if strconv.FormatInt(-255, 16) == "-ff" { pass = pass + 1 }

    // FormatInt — base 36
    if strconv.FormatInt(35, 36) == "z" { pass = pass + 1 }
    if strconv.FormatInt(36, 36) == "10" { pass = pass + 1 }

    // ParseInt — base 2
    var v1 int = 0
    var e1 error = nil
    v1, e1 = strconv.ParseInt("101", 2)
    if e1 == nil {
        if v1 == 5 { pass = pass + 1 }
    }

    // ParseInt — base 16, mixed case
    var v2 int = 0
    var e2 error = nil
    v2, e2 = strconv.ParseInt("FF", 16)
    if e2 == nil {
        if v2 == 255 { pass = pass + 1 }
    }

    var v3 int = 0
    var e3 error = nil
    v3, e3 = strconv.ParseInt("ff", 16)
    if e3 == nil {
        if v3 == 255 { pass = pass + 1 }
    }

    // ParseInt — negative
    var v4 int = 0
    var e4 error = nil
    v4, e4 = strconv.ParseInt("-2a", 16)
    if e4 == nil {
        if v4 == -42 { pass = pass + 1 }
    }

    // ParseInt — base 36
    var v5 int = 0
    var e5 error = nil
    v5, e5 = strconv.ParseInt("z", 36)
    if e5 == nil {
        if v5 == 35 { pass = pass + 1 }
    }

    // Roundtrip: format then parse
    var v6 int = 0
    var e6 error = nil
    var s string = strconv.FormatInt(12345, 8)
    v6, e6 = strconv.ParseInt(s, 8)
    if e6 == nil {
        if v6 == 12345 { pass = pass + 1 }
    }

    // Error paths
    var v7 int = 0
    var e7 error = nil
    v7, e7 = strconv.ParseInt("", 10)
    if e7 != nil {
        if v7 == 0 { pass = pass + 1 }
    }

    var v8 int = 0
    var e8 error = nil
    v8, e8 = strconv.ParseInt("9", 8)        // 9 invalid in base 8
    if e8 != nil {
        if v8 == 0 { pass = pass + 1 }
    }

    var v9 int = 0
    var e9 error = nil
    v9, e9 = strconv.ParseInt("abc", 1)      // base out of range
    if e9 != nil {
        if v9 == 0 { pass = pass + 1 }
    }

    log.Println("pass=%d/17", pass)
    if pass == 17 { ret 42 }
    ret 0
}
