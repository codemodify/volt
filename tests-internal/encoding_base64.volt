// encoding/base64 smoke test — encode + decode round-trip + errors.

package main

import "encoding/base64"
import "log"

fun main() int {
    var pass int = 0

    // Encode — empty + RFC 4648 §10 examples.
    if base64.EncodeToString("") == "" { pass = pass + 1 }
    if base64.EncodeToString("f")      == "Zg=="     { pass = pass + 1 }
    if base64.EncodeToString("fo")     == "Zm8="     { pass = pass + 1 }
    if base64.EncodeToString("foo")    == "Zm9v"     { pass = pass + 1 }
    if base64.EncodeToString("foob")   == "Zm9vYg==" { pass = pass + 1 }
    if base64.EncodeToString("fooba")  == "Zm9vYmE=" { pass = pass + 1 }
    if base64.EncodeToString("foobar") == "Zm9vYmFy" { pass = pass + 1 }

    // High-bit byte: 0xff alone → "/w=="
    if base64.EncodeToString("\xff") == "/w==" { pass = pass + 1 }
    // Two bytes 0xab 0xcd → "q80="
    if base64.EncodeToString("\xab\xcd") == "q80=" { pass = pass + 1 }

    // Decode — round-trip the same RFC vectors.
    var d1 string = ""
    var e1 error = nil
    d1, e1 = base64.DecodeString("Zm9vYmFy")
    if e1 == nil { if d1 == "foobar" { pass = pass + 1 } }

    var d2 string = ""
    var e2 error = nil
    d2, e2 = base64.DecodeString("Zg==")
    if e2 == nil { if d2 == "f" { pass = pass + 1 } }

    var d3 string = ""
    var e3 error = nil
    d3, e3 = base64.DecodeString("Zm8=")
    if e3 == nil { if d3 == "fo" { pass = pass + 1 } }

    // Round-trip a binary payload through encode → decode.
    var payload string = "\x00\x01\x02hello\xff\xfe\xfd"
    var enc string = base64.EncodeToString(payload)
    var dec string = ""
    var derr error = nil
    dec, derr = base64.DecodeString(enc)
    if derr == nil { if dec == payload { pass = pass + 1 } }

    // Error: wrong length (not multiple of 4).
    var x1 string = ""
    var er1 error = nil
    x1, er1 = base64.DecodeString("Zg=")
    if er1 != nil { if x1 == "" { pass = pass + 1 } }

    // Error: bad char.
    var x2 string = ""
    var er2 error = nil
    x2, er2 = base64.DecodeString("Z!==")
    if er2 != nil { if x2 == "" { pass = pass + 1 } }

    log.Println("pass=%d/15", pass)
    if pass == 15 { ret 42 }
    ret 0
}
