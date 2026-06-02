// HMAC-SHA1 smoke — RFC 2202 vectors.

package main

import "crypto/hmac"
import "log"

fun main() int {
    var pass int = 0

    // RFC 2202 Test Case 1: key = 0x0b * 20, msg = "Hi There"
    var k1 string = "\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b"
    if hmac.Sum1Hex(k1, "Hi There") ==
        "b617318655057264e28bc0b6fb378c8ef146be00" {
        pass = pass + 1
    }
    // RFC 2202 Test Case 2: key = "Jefe", msg = "what do ya want for nothing?"
    if hmac.Sum1Hex("Jefe", "what do ya want for nothing?") ==
        "effcdf6ae5eb2fa2d27416d5f184df9c259a7c79" {
        pass = pass + 1
    }
    // Short key
    if hmac.Sum1Hex("k", "abc") ==
        "f9bef091fe00d9f5128593836dba99e193f08174" {
        pass = pass + 1
    }
    // Empty key + empty msg
    if hmac.Sum1Hex("", "") ==
        "fbdb1d1b18aa6c08324b7d64b71fb76370690e1d" {
        pass = pass + 1
    }
    // Oversized key (>64 bytes) collapses via SHA-1.
    var bigKey string = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"
    if hmac.Sum1Hex(bigKey, "test") ==
        "78c0180d74094f81a6226fc1a54374fc2c8a3bec" {
        pass = pass + 1
    }

    log.Println("pass=%d/5", pass)
    if pass == 5 { ret 42 }
    ret 0
}
