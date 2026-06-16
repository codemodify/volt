// Package rand: cryptographically-strong randomness via the Linux
// getrandom(2) syscall. Suitable for nonces, salts, tokens, session
// IDs — anything the math/rand package would be wrong for.
//
// Surface:
//   Bytes(n int) string       — n random bytes (may return <n bytes
//                                on a short read; len(s) tells you)
//   Hex(n int)   string       — n random bytes hex-encoded (2n chars)

package rand

import "syscall"
import "bytes"

// Bytes returns up to n cryptographically-strong random bytes from
// the OS. Caller should check `len(result) == n` if a short read
// would matter (the kernel may return less than requested on
// interrupt).
fun Bytes(n int) string {
    if n <= 0 { ret "" }
    ret syscall.GetRandom(n)
}

// Hex returns 2n lowercase hex characters representing n random
// bytes. Convenient for session IDs and one-shot tokens.
fun Hex(n int) string {
    var d string = Bytes(n)
    var b bytes.Builder = new bytes.Builder{}
    var dn int = len(d)
    for i:=0; i < dn; i++ {
        var by int = d[i] & 255
        b.WriteByte(hexChar(by >> 4))
        b.WriteByte(hexChar(by & 15))
    }
    ret b.String()
}

fun hexChar(n int) byte {
    if n < 10 { ret 48 + n }
    ret 87 + n
}

// Int returns a cryptographically-strong random non-negative
// integer in [0, max). max must be > 0; non-positive max returns 0.
// Uses 7 random bytes (56 bits) so the accumulated value always
// fits in a positive int — avoiding the sign-bit / MinInt-overflow
// trickery of an 8-byte accumulator. Mod bias is negligible for
// max << 2^56.
fun Int(max int) int {
    if max <= 0 { ret 0 }
    var s string = syscall.GetRandom(7)
    var n int = len(s)
    if n == 0 { ret 0 }
    var v int = 0
    for i := 0; i < n; i++ {
        var b int = s[i] & 255
        v = (v << 8) | b
    }
    ret v % max
}

// IntRange returns a cryptographically-strong random integer in
// `[lo, hi)`. Requires hi > lo; on a non-positive range it returns
// `lo` deterministically. Same mod-bias caveat as `Int` — negligible
// for ranges well below 2^56.
fun IntRange(lo int, hi int) int {
    if hi <= lo { ret lo }
    var span int = hi - lo
    ret lo + Int(span)
}

// Bool returns a cryptographically-strong random boolean — exactly
// 50/50 over a single sampled byte's low bit. Useful for coin-flip
// branching, randomized A/B selection, fuzz-style permutation.
fun Bool() bool {
    var s string = syscall.GetRandom(1)
    if len(s) == 0 { ret false }
    if (s[0] & 1) == 1 { ret true }
    ret false
}

// String returns a random n-byte string drawn from `alphabet`. Each
// position is `randomByte % len(alphabet)` so there is mild modulo
// bias when 256 % len(alphabet) != 0 (e.g. ~0.4% for 62-char
// alphanumerics) — acceptable for tokens / session IDs / nonces,
// not for cryptographic ballot selection. n <= 0 or empty alphabet
// returns "".
fun String(n int, alphabet string) string {
    if n <= 0 { ret "" }
    var alen int = len(alphabet)
    if alen == 0 { ret "" }
    var randBytes string = Bytes(n)
    var rn int = len(randBytes)
    if rn == 0 { ret "" }
    var b bytes.Builder = new bytes.Builder{}
    for i := 0; i < rn; i++ {
        var byteVal int = randBytes[i] & 255
        var idx int = byteVal % alen
        b.WriteByte(alphabet[idx])
    }
    ret b.String()
}

// AlphanumString returns n random alphanumeric characters
// ([A-Za-z0-9]) — a URL-safe, human-typeable readable token. Thin
// wrapper over String with the 62-char alphanumeric alphabet. Useful
// for session IDs and short tokens; for longer cryptographic
// secrets, Hex is denser per byte of input.
fun AlphanumString(n int) string {
    ret String(n, "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
}
