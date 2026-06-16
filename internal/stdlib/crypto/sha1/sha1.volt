// Package sha1: SHA-1 hash (FIPS 180-4).
//
// Surface:
//   Sum(msg string) string     — 20-byte binary digest
//   SumHex(msg string) string  — 40-char lowercase hex digest
//
// SHA-1 is broken for collision resistance — use crypto/sha256 for
// anything new. This package exists for git interop, legacy
// signatures, and HMAC-SHA1 (RFC 2202).

package sha1

import "bytes"

const mask32 int = 4294967295  // 0xFFFFFFFF

// rotl32 is a 32-bit left rotation. x is guaranteed in [0, 2^32) by
// callers (every result masked to 32 bits), so `>>` is effectively
// logical here even though volt's `>>` is arithmetic.
fun rotl32(x int, n int) int {
    var lo int = (x << n) & mask32
    var hi int = (x >> (32 - n)) & mask32
    ret (lo | hi) & mask32
}

// padded mirrors sha256's padding: append 0x80, zero-pad to length
// ≡ 56 (mod 64), then 8-byte big-endian bit length.
fun padded(msg string) string {
    var n int = len(msg)
    var out string = msg
    out = out + chr(128)
    var padZeros int = 56 - ((n + 1) % 64)
    if padZeros < 0 { padZeros = padZeros + 64 }
    for i:=0; i < padZeros; i++ {
        out = out + chr(0)
    }
    var bits int = n * 8
    out = out + chr((bits >> 56) & 255)
    out = out + chr((bits >> 48) & 255)
    out = out + chr((bits >> 40) & 255)
    out = out + chr((bits >> 32) & 255)
    out = out + chr((bits >> 24) & 255)
    out = out + chr((bits >> 16) & 255)
    out = out + chr((bits >>  8) & 255)
    out = out + chr(bits         & 255)
    ret out
}

// roundF returns the per-round Boolean function. FIPS §6.1.2.
fun roundF(t int, b int, c int, d int) int {
    if t < 20 { ret (b & c) | ((mask32 ^ b) & d) }            // Ch
    if t < 40 { ret b ^ c ^ d }                                // Parity
    if t < 60 { ret (b & c) | (b & d) | (c & d) }              // Maj
    ret b ^ c ^ d                                              // Parity
}

// roundK returns the per-round additive constant.
fun roundK(t int) int {
    if t < 20 { ret 1518500249 }   // 0x5A827999
    if t < 40 { ret 1859775393 }   // 0x6ED9EBA1
    if t < 60 { ret 2400959708 }   // 0x8F1BBCDC
    ret 3395469782                 // 0xCA62C1D6
}

// Sum returns the 20-byte SHA-1 digest of msg.
fun Sum(msg string) string {
    var p string = padded(msg)
    var blocks int = len(p) / 64

    var h0 int = 1732584193   // 0x67452301
    var h1 int = 4023233417   // 0xEFCDAB89
    var h2 int = 2562383102   // 0x98BADCFE
    var h3 int = 271733878    // 0x10325476
    var h4 int = 3285377520   // 0xC3D2E1F0

    var w []int = new(80) []int {}
    for blk:=0; blk < blocks; blk++ {
        var base int = blk * 64
        for t:=0; t < 16; t++ {
            var idx int = base + t * 4
            var b0 int = p[idx]   & 255
            var b1 int = p[idx+1] & 255
            var b2 int = p[idx+2] & 255
            var b3 int = p[idx+3] & 255
            w[t] = ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) & mask32
        }
        for t:=16; t < 80; t++ {
            var x int = w[t-3] ^ w[t-8] ^ w[t-14] ^ w[t-16]
            w[t] = rotl32(x, 1)
        }

        var a int = h0
        var b int = h1
        var c int = h2
        var d int = h3
        var e int = h4

        for t:=0; t < 80; t++ {
            var tmp int = (rotl32(a, 5) + roundF(t, b, c, d) + e + w[t] + roundK(t)) & mask32
            e = d
            d = c
            c = rotl32(b, 30)
            b = a
            a = tmp
        }

        h0 = (h0 + a) & mask32
        h1 = (h1 + b) & mask32
        h2 = (h2 + c) & mask32
        h3 = (h3 + d) & mask32
        h4 = (h4 + e) & mask32
    }

    var out string = ""
    out = out + word32be(h0)
    out = out + word32be(h1)
    out = out + word32be(h2)
    out = out + word32be(h3)
    out = out + word32be(h4)
    ret out
}

fun word32be(w int) string {
    var s string = ""
    s = s + chr((w >> 24) & 255)
    s = s + chr((w >> 16) & 255)
    s = s + chr((w >>  8) & 255)
    s = s + chr(w         & 255)
    ret s
}

// SumHex returns the 40-char lowercase-hex SHA-1 digest.
fun SumHex(msg string) string {
    var d string = Sum(msg)
    var b bytes.Builder = new bytes.Builder{}
    var n int = len(d)
    for i:=0; i < n; i++ {
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
