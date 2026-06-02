// HMAC-MD5 smoke — RFC 2104 test vectors (Python-cross-checked).

package main

import "crypto/hmac"
import "log"

fun main() int {
    var pass int = 0

    // RFC 2104 Test Case 1: key = 0x0b * 16, msg = "Hi There"
    var k1 string = "\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b"
    if hmac.SumMD5Hex(k1, "Hi There") ==
        "9294727a3638bb1c13f48ef8158bfc9d" {
        pass = pass + 1
    }
    // RFC 2104 Test Case 2: key = "Jefe", msg = "what do ya want for nothing?"
    if hmac.SumMD5Hex("Jefe", "what do ya want for nothing?") ==
        "750c783e6ab0b503eaa86e310a5db738" {
        pass = pass + 1
    }
    // Empty key + empty msg.
    if hmac.SumMD5Hex("", "") ==
        "74e6f7298a9c2d168935f58c001bad88" {
        pass = pass + 1
    }
    // Single-byte key.
    if hmac.SumMD5Hex("k", "abc") ==
        "75972c9c6569f2f407752ddb02ac79de" {
        pass = pass + 1
    }
    // Oversized key (>64 bytes) collapses via MD5.
    var bigKey string = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
    if hmac.SumMD5Hex(bigKey, "test") ==
        "2520ee2e82e01d7b95bc93516d8a5f35" {
        pass = pass + 1
    }

    log.Println("pass=%d/5", pass)
    if pass == 5 { ret 42 }
    ret 0
}
