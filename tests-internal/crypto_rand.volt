// crypto/rand smoke — actual randomness can't be asserted on
// contents (it's random by design), but we can verify the
// shape contract: length matches what we asked for, two
// independent calls don't return the same bytes, hex output
// is twice the byte length and only contains hex digits.

package main

import "crypto/rand"
import "log"

fun isHexChar(b byte) bool {
    if b >= 48 { if b <= 57 { ret true } }   // 0-9
    if b >= 97 { if b <= 102 { ret true } }  // a-f
    ret false
}

fun main() int {
    var pass int = 0

    // Bytes returns the requested length.
    var b16 string = rand.Bytes(16)
    if len(b16) == 16 { pass = pass + 1 }

    var b32 string = rand.Bytes(32)
    if len(b32) == 32 { pass = pass + 1 }

    // Edge cases
    if rand.Bytes(0) == "" { pass = pass + 1 }
    if rand.Bytes(-5) == "" { pass = pass + 1 }

    // Two independent calls of 32 bytes are (overwhelmingly) different.
    var a string = rand.Bytes(32)
    var c string = rand.Bytes(32)
    if a != c { pass = pass + 1 }

    // Hex output is 2× the byte length.
    var h string = rand.Hex(16)
    if len(h) == 32 { pass = pass + 1 }

    // Hex output only contains [0-9a-f].
    var allHex bool = true
    var hn int = len(h)
    for i:=0; i < hn; i++ {
        if !isHexChar(h[i]) { allHex = false }
    }
    if allHex { pass = pass + 1 }

    // Two Hex calls differ.
    var h1 string = rand.Hex(24)
    var h2 string = rand.Hex(24)
    if h1 != h2 { pass = pass + 1 }

    log.Println("pass=%d/8", pass)
    if pass == 8 { ret 42 }
    ret 0
}
