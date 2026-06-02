// Stress test for the O(n) string-build wins (Pass 118..121).
// Pre-refactor: this loop would do ~5e7 byte-copies and the test
// would visibly stall (or time out under the 10s scripts/run_smoke.sh
// budget). Post-refactor: completes in O(n) total work — well under
// a second on commodity hardware.

package main

import "strings"
import "encoding/hex"
import "crypto/sha256"
import "log"

fun main() int {
    var pass int = 0

    // ---- strings.Repeat on a 10 KB output --------------------------
    // 10000 single-char repeats = exactly 10000 chars. Pre-refactor
    // this would do ~50 million byte copies; now it's O(10000).
    var s1 string = strings.Repeat("x", 10000)
    if len(s1) == 10000 { pass = pass + 1 }
    if s1[0] == 120 { if s1[9999] == 120 { pass = pass + 1 } }   // 'x'

    // ---- strings.ToLower on a 5 KB input ---------------------------
    var upper string = strings.Repeat("ABC", 1500)   // 4500 chars
    var lower string = strings.ToLower(upper)
    if len(lower) == 4500 { pass = pass + 1 }
    if lower[0] == 97  { pass = pass + 1 }   // 'a'
    if lower[1] == 98  { pass = pass + 1 }   // 'b'
    if lower[2] == 99  { pass = pass + 1 }   // 'c'

    // ---- hex.EncodeToString on a 2 KB input ------------------------
    // 2 KB → 4 KB hex output. O(n²) would be ~16 million copies; O(n)
    // is ~4000 byte writes.
    var raw string = strings.Repeat("\x00\xff", 1000)   // alternating 2000 bytes
    var encoded string = hex.EncodeToString(raw)
    if len(encoded) == 4000 { pass = pass + 1 }
    if encoded[0] == 48 { if encoded[1] == 48 { pass = pass + 1 } }   // "00"
    if encoded[2] == 102 { if encoded[3] == 102 { pass = pass + 1 } } // "ff"

    // ---- strings.Replace many matches ------------------------------
    // Replace "a" with "BB" in a 3000-char "a"-string → 6000-char output.
    var src string = strings.Repeat("a", 3000)
    var doubled string = strings.Replace(src, "a", "BB")
    if len(doubled) == 6000 { pass = pass + 1 }
    if doubled[0] == 66 { if doubled[1] == 66 { pass = pass + 1 } }   // "BB"

    // ---- sha256 of a 1 KB input ------------------------------------
    // SHA-256's inner state machine is O(n), but the post-hash hex
    // encoding now uses bytes.Builder too.
    var blob string = strings.Repeat("x", 1024)
    var hash string = sha256.SumHex(blob)
    if len(hash) == 64 { pass = pass + 1 }
    // sha256(b"x" * 1024) is fixed — Python-cross-checked.
    if hash == "49abd65bbf7f7e40c7055093ed2e3fd75f2f602f2c5fcf955c213e3135eb03f7" {
        pass = pass + 1
    }

    log.Println("pass=%d/13", pass)
    if pass == 13 { ret 42 }
    ret 0
}
