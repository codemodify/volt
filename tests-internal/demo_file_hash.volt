// Integration demo: write a file, read it back, hash it, sign it with
// HMAC, and base64-encode the signature. Exercises five stdlib
// packages together to prove the surface composes.

package main

import "os"
import "crypto/sha256"
import "crypto/hmac"
import "encoding/base64"
import "encoding/hex"
import "time"
import "strconv"
import "log"

fun main() int {
    var pass int = 0
    var stamp int = time.Mono()
    var path string = "/tmp/volt_demo_" + strconv.Itoa(stamp) + ".txt"

    // ---- 1. Write -------------------------------------------------
    var content string = "The quick brown fox jumps over the lazy dog"
    if os.WriteFile(path, content, 420) != nil { ret 0 }

    // ---- 2. Read it back ------------------------------------------
    var data string = ""
    var err error = nil
    data, err = os.ReadFile(path)
    if err == nil { pass = pass + 1 }
    if data == content { pass = pass + 1 }

    // ---- 3. SHA-256 of the read bytes -----------------------------
    // Cross-checked: SHA-256 of the pangram is well-known.
    var digest string = sha256.SumHex(data)
    if digest == "d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592" {
        pass = pass + 1
    }

    // ---- 4. HMAC-SHA256 with a key --------------------------------
    var tag string = hmac.Sum256Hex("secret-key", data)
    // Python-cross-checked HMAC-SHA256("secret-key", pangram).hexdigest()
    if tag == "affee3b4888c714d8369e419b5e51d1ff7c024b64a94d76b8dd53c8fb5d0a2dc" {
        pass = pass + 1
    }

    // ---- 5. Base64-encode the binary HMAC tag ---------------------
    var rawTag string = hmac.Sum256("secret-key", data)
    var b64 string = base64.EncodeToString(rawTag)
    // 32 raw bytes → 44 chars (32/3 = 10.67 → 11 groups → 44 chars w/ pad)
    if len(b64) == 44 { pass = pass + 1 }

    // ---- 6. Decode the base64 → hex round-trip --------------------
    var roundtrip string = ""
    var derr error = nil
    roundtrip, derr = base64.DecodeString(b64)
    if derr == nil { pass = pass + 1 }
    if hex.EncodeToString(roundtrip) == tag { pass = pass + 1 }

    // ---- 7. Clean up ----------------------------------------------
    if os.Remove(path) == 0 { pass = pass + 1 }
    if !os.Exists(path) { pass = pass + 1 }

    log.Println("pass=%d/9", pass)
    if pass == 9 { ret 42 }
    ret 0
}
