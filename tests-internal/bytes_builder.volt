// bytes.Builder smoke — exercises the O(n) string-build path via
// the new volt_string_from_bytes runtime intrinsic.

package main

import "bytes"
import "log"

fun main() int {
    var pass int = 0

    // Empty builder
    var b *bytes.Builder = bytes.NewBuilder()
    if b.Len() == 0 { pass = pass + 1 }
    if b.String() == "" { pass = pass + 1 }

    // WriteByte
    b.WriteByte(72)   // 'H'
    b.WriteByte(105)  // 'i'
    if b.Len() == 2 { pass = pass + 1 }
    if b.String() == "Hi" { pass = pass + 1 }

    // WriteString
    b.WriteString(" there")
    if b.Len() == 8 { pass = pass + 1 }
    if b.String() == "Hi there" { pass = pass + 1 }

    // Reset
    b.Reset()
    if b.Len() == 0 { pass = pass + 1 }
    if b.String() == "" { pass = pass + 1 }

    // Reuse after reset
    b.WriteString("Reset and continue")
    if b.String() == "Reset and continue" { pass = pass + 1 }

    // Big build that crosses the initial 16-byte capacity.
    var big *bytes.Builder = bytes.NewBuilder()
    for i := range 100 {
        big.WriteByte(97)   // 'a' × 100
        if i < 0 { ret 0 }  // dead use to keep i live
    }
    if big.Len() == 100 { pass = pass + 1 }
    var s string = big.String()
    if len(s) == 100 { pass = pass + 1 }
    // First and last chars are 'a' (98 = 'b' if any indexing went wrong).
    if s[0]  == 97 { pass = pass + 1 }
    if s[99] == 97 { pass = pass + 1 }

    // WriteString a chunk equal to current capacity (forces a grow).
    var grow *bytes.Builder = bytes.NewBuilder()
    grow.WriteString("0123456789ABCDEF")    // exactly 16 — fills initial buf
    grow.WriteString("more bytes here")     // forces grow
    if grow.String() == "0123456789ABCDEFmore bytes here" { pass = pass + 1 }

    log.Println("pass=%d/14", pass)
    if pass == 14 { ret 42 }
    ret 0
}
