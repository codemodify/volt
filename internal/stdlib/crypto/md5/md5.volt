// Package md5: MD5 hash (RFC 1321).
//
// Surface:
//   Sum(msg string) string     — 16-byte binary digest
//   SumHex(msg string) string  — 32-char lowercase hex digest
//
// MD5 is cryptographically broken — use crypto/sha256 for anything
// requiring collision resistance. This package exists for cache
// keys, ETags, content-addressed lookups, and legacy interop.
//
// Same 32-bit-on-int64 emulation as crypto/sha1 / crypto/sha256:
// every step masks with mask32 to stay in the unsigned-32 window.
// MD5 is LITTLE-endian (vs SHA's big-endian) — block word reads and
// the final-length encoding both reflect that.

package md5

import "bytes"

const mask32 int = 4294967295  // 0xFFFFFFFF

fun rotl32(x int, n int) int {
    var lo int = (x << n) & mask32
    var hi int = (x >> (32 - n)) & mask32
    ret (lo | hi) & mask32
}

// Padded length: append 0x80, zero-pad to length ≡ 56 (mod 64),
// then 8-byte little-endian bit-length.
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
    out = out + chr(bits         & 255)
    out = out + chr((bits >>  8) & 255)
    out = out + chr((bits >> 16) & 255)
    out = out + chr((bits >> 24) & 255)
    out = out + chr((bits >> 32) & 255)
    out = out + chr((bits >> 40) & 255)
    out = out + chr((bits >> 48) & 255)
    out = out + chr((bits >> 56) & 255)
    ret out
}

// Per-round Boolean functions, RFC 1321 §3.4.
fun fF(b int, c int, d int) int { ret (b & c) | ((mask32 ^ b) & d) }
fun fG(b int, c int, d int) int { ret (b & d) | (c & (mask32 ^ d)) }
fun fH(b int, c int, d int) int { ret b ^ c ^ d }
fun fI(b int, c int, d int) int { ret c ^ (b | (mask32 ^ d)) }

// kIdx: message-word index per round.
fun kIdx(i int) int {
    if i < 16 { ret i }
    if i < 32 { ret (5 * i + 1) % 16 }
    if i < 48 { ret (3 * i + 5) % 16 }
    ret (7 * i) % 16
}

// rotS: per-round shift amount.
fun rotS(i int) int {
    if i < 16 {
        var r int = i % 4
        if r == 0 { ret 7 }
        if r == 1 { ret 12 }
        if r == 2 { ret 17 }
        ret 22
    }
    if i < 32 {
        var r int = i % 4
        if r == 0 { ret 5 }
        if r == 1 { ret 9 }
        if r == 2 { ret 14 }
        ret 20
    }
    if i < 48 {
        var r int = i % 4
        if r == 0 { ret 4 }
        if r == 1 { ret 11 }
        if r == 2 { ret 16 }
        ret 23
    }
    var r int = i % 4
    if r == 0 { ret 6 }
    if r == 1 { ret 10 }
    if r == 2 { ret 15 }
    ret 21
}

// tConst: T[i] = floor(abs(sin(i+1)) * 2^32), the 64 per-round
// additive constants from RFC 1321.
fun tConst(i int) int {
    if i == 0  { ret 3614090360 }
    if i == 1  { ret 3905402710 }
    if i == 2  { ret 606105819  }
    if i == 3  { ret 3250441966 }
    if i == 4  { ret 4118548399 }
    if i == 5  { ret 1200080426 }
    if i == 6  { ret 2821735955 }
    if i == 7  { ret 4249261313 }
    if i == 8  { ret 1770035416 }
    if i == 9  { ret 2336552879 }
    if i == 10 { ret 4294925233 }
    if i == 11 { ret 2304563134 }
    if i == 12 { ret 1804603682 }
    if i == 13 { ret 4254626195 }
    if i == 14 { ret 2792965006 }
    if i == 15 { ret 1236535329 }
    if i == 16 { ret 4129170786 }
    if i == 17 { ret 3225465664 }
    if i == 18 { ret 643717713  }
    if i == 19 { ret 3921069994 }
    if i == 20 { ret 3593408605 }
    if i == 21 { ret 38016083   }
    if i == 22 { ret 3634488961 }
    if i == 23 { ret 3889429448 }
    if i == 24 { ret 568446438  }
    if i == 25 { ret 3275163606 }
    if i == 26 { ret 4107603335 }
    if i == 27 { ret 1163531501 }
    if i == 28 { ret 2850285829 }
    if i == 29 { ret 4243563512 }
    if i == 30 { ret 1735328473 }
    if i == 31 { ret 2368359562 }
    if i == 32 { ret 4294588738 }
    if i == 33 { ret 2272392833 }
    if i == 34 { ret 1839030562 }
    if i == 35 { ret 4259657740 }
    if i == 36 { ret 2763975236 }
    if i == 37 { ret 1272893353 }
    if i == 38 { ret 4139469664 }
    if i == 39 { ret 3200236656 }
    if i == 40 { ret 681279174  }
    if i == 41 { ret 3936430074 }
    if i == 42 { ret 3572445317 }
    if i == 43 { ret 76029189   }
    if i == 44 { ret 3654602809 }
    if i == 45 { ret 3873151461 }
    if i == 46 { ret 530742520  }
    if i == 47 { ret 3299628645 }
    if i == 48 { ret 4096336452 }
    if i == 49 { ret 1126891415 }
    if i == 50 { ret 2878612391 }
    if i == 51 { ret 4237533241 }
    if i == 52 { ret 1700485571 }
    if i == 53 { ret 2399980690 }
    if i == 54 { ret 4293915773 }
    if i == 55 { ret 2240044497 }
    if i == 56 { ret 1873313359 }
    if i == 57 { ret 4264355552 }
    if i == 58 { ret 2734768916 }
    if i == 59 { ret 1309151649 }
    if i == 60 { ret 4149444226 }
    if i == 61 { ret 3174756917 }
    if i == 62 { ret 718787259  }
    ret 3951481745
}

// fnFor returns Fn(b, c, d) for round i.
fun fnFor(i int, b int, c int, d int) int {
    if i < 16 { ret fF(b, c, d) }
    if i < 32 { ret fG(b, c, d) }
    if i < 48 { ret fH(b, c, d) }
    ret fI(b, c, d)
}

// Sum returns the 16-byte MD5 digest of msg.
fun Sum(msg string) string {
    var p string = padded(msg)
    var blocks int = len(p) / 64

    var h0 int = 1732584193   // 0x67452301
    var h1 int = 4023233417   // 0xEFCDAB89
    var h2 int = 2562383102   // 0x98BADCFE
    var h3 int = 271733878    // 0x10325476

    var m []int = new(16) []int {}
    for blk:=0; blk < blocks; blk++ {
        var base int = blk * 64
        // Little-endian 32-bit word read.
        for t:=0; t < 16; t++ {
            var idx int = base + t * 4
            var b0 int = p[idx]   & 255
            var b1 int = p[idx+1] & 255
            var b2 int = p[idx+2] & 255
            var b3 int = p[idx+3] & 255
            m[t] = (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)) & mask32
        }

        var a int = h0
        var b int = h1
        var c int = h2
        var d int = h3

        for i:=0; i < 64; i++ {
            var f int = fnFor(i, b, c, d)
            var sum int = (a + f + m[kIdx(i)] + tConst(i)) & mask32
            var newB int = (b + rotl32(sum, rotS(i))) & mask32
            a = d
            d = c
            c = b
            b = newB
        }

        h0 = (h0 + a) & mask32
        h1 = (h1 + b) & mask32
        h2 = (h2 + c) & mask32
        h3 = (h3 + d) & mask32
    }

    var out string = ""
    out = out + word32le(h0)
    out = out + word32le(h1)
    out = out + word32le(h2)
    out = out + word32le(h3)
    ret out
}

fun word32le(w int) string {
    var s string = ""
    s = s + chr(w         & 255)
    s = s + chr((w >>  8) & 255)
    s = s + chr((w >> 16) & 255)
    s = s + chr((w >> 24) & 255)
    ret s
}

// SumHex returns the 32-char lowercase-hex MD5 digest.
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
