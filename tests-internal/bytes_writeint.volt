// bytes.Builder.WriteInt smoke — decimal int formatter.

package main

import "bytes"
import "log"

fun emit(n int) string {
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteInt(n)
    ret b.String()
}

fun main() int {
    var pass int = 0

    if emit(0)          == "0"          { pass = pass + 1 }
    if emit(1)          == "1"          { pass = pass + 1 }
    if emit(9)          == "9"          { pass = pass + 1 }
    if emit(10)         == "10"         { pass = pass + 1 }
    if emit(99)         == "99"         { pass = pass + 1 }
    if emit(100)        == "100"        { pass = pass + 1 }
    if emit(12345)      == "12345"      { pass = pass + 1 }
    if emit(-1)         == "-1"         { pass = pass + 1 }
    if emit(-99)        == "-99"        { pass = pass + 1 }
    if emit(-100)       == "-100"       { pass = pass + 1 }
    if emit(9223372036854775807) == "9223372036854775807" { pass = pass + 1 }   // MaxInt
    if emit(-9223372036854775807 - 1) == "-9223372036854775808" { pass = pass + 1 } // MinInt
    if emit(1000000)    == "1000000"    { pass = pass + 1 }
    if emit(-1000000)   == "-1000000"   { pass = pass + 1 }

    // Mixed with WriteString
    var b *bytes.Builder = bytes.NewBuilder()
    b.WriteString("count: ")
    b.WriteInt(42)
    b.WriteString(" items")
    if b.String() == "count: 42 items" { pass = pass + 1 }

    log.Println("pass=%d/15", pass)
    if pass == 15 { ret 42 }
    ret 0
}
