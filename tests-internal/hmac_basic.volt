// crypto/hmac HMAC-SHA256 smoke — RFC 4231 test vectors.

package main

import "crypto/hmac"
import "log"

fun main() int {
    var pass int = 0

    // RFC 4231 Test Case 1: key = 0x0b * 20, msg = "Hi There"
    var k1 string = "\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b\x0b"
    if hmac.Sum256Hex(k1, "Hi There") ==
        "b0344c61d8db38535ca8afceaf0bf12b881dc200c9833da726e9376c2e32cff7" {
        pass = pass + 1
    }

    // RFC 4231 Test Case 2: key = "Jefe", msg = "what do ya want for nothing?"
    if hmac.Sum256Hex("Jefe", "what do ya want for nothing?") ==
        "5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843" {
        pass = pass + 1
    }

    // Single-byte key (short). Python-cross-checked.
    if hmac.Sum256Hex("k", "abc") ==
        "342e519ce0ad6c03a36b98eeb3f1d130db4813b9df4d1160eda488d712dc78ee" {
        pass = pass + 1
    }

    // Empty key + empty msg (smoke).
    if hmac.Sum256Hex("", "") ==
        "b613679a0814d9ec772f95d778c35fc5ff1697c493715653c6c712144292c5ad" {
        pass = pass + 1
    }

    // Oversized key (> 64 bytes): hashed down to 32 bytes via SHA-256
    // then zero-padded to the 64-byte HMAC block size. Python-cross-checked.
    var bigKey string = "0123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890123456789"   // 100 bytes
    if hmac.Sum256Hex(bigKey, "test") ==
        "3e4038a0d1f8ca4cd74ace5884535980e4c7c881ee9780b9c6492f07c456b245" {
        pass = pass + 1
    }

    log.Println("pass=%d/5", pass)
    if pass == 5 { ret 42 }
    ret 0
}
