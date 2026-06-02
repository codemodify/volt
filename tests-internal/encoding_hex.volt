// encoding/hex smoke test — encode + decode round-trip, error cases.

package main

import "encoding/hex"
import "log"

fun main() int {
    var pass int = 0

    // Encode
    if hex.EncodeToString("") == "" { pass = pass + 1 }
    if hex.EncodeToString("\x00\x01\x02") == "000102" { pass = pass + 1 }
    if hex.EncodeToString("hi") == "6869" { pass = pass + 1 }       // 'h'=0x68, 'i'=0x69
    if hex.EncodeToString("\xff") == "ff" { pass = pass + 1 }
    if hex.EncodeToString("\xab\xcd") == "abcd" { pass = pass + 1 }

    // Decode
    var d1 string = ""
    var e1 error = nil
    d1, e1 = hex.DecodeString("6869")
    if e1 == nil {
        if d1 == "hi" { pass = pass + 1 }
    }

    // Mixed case input should still decode
    var d2 string = ""
    var e2 error = nil
    d2, e2 = hex.DecodeString("AbCd")
    if e2 == nil {
        if d2 == "\xab\xcd" { pass = pass + 1 }
    }

    // Round-trip via a random-looking byte string
    var payload string = "hello, world\n"
    var enc string = hex.EncodeToString(payload)
    var dec string = ""
    var derr error = nil
    dec, derr = hex.DecodeString(enc)
    if derr == nil {
        if dec == payload { pass = pass + 1 }
    }

    // Error: odd length
    var x1 string = ""
    var oerr error = nil
    x1, oerr = hex.DecodeString("abc")
    if oerr != nil {
        if x1 == "" { pass = pass + 1 }
    }

    // Error: non-hex char
    var x2 string = ""
    var nerr error = nil
    x2, nerr = hex.DecodeString("zz")
    if nerr != nil {
        if x2 == "" { pass = pass + 1 }
    }

    log.Println("pass=%d/10", pass)
    if pass == 10 { ret 42 }
    ret 0
}
