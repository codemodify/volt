// Package sha256: SHA-256 hash (FIPS 180-4).
//
// Surface:
//   Sum(msg string) string     — 32-byte binary digest
//   SumHex(msg string) string  — 64-char lowercase hex digest
//
// Pure-volt implementation over the int + bitwise/shift ops.
// `int` is signed 64-bit; every 32-bit operation masks with
// `0xFFFFFFFF` to stay within the unsigned 32-bit window the
// algorithm expects.

package sha256

import "bytes"

const mask32 int = 4294967295  // 0xFFFFFFFF

// rotr32 returns a 32-bit right rotation of x by n bits (n in 0..31).
fun rotr32(x int, n int) int {
    var lo int = (x >> n) & mask32
    var hi int = (x << (32 - n)) & mask32
    ret (lo | hi) & mask32
}

// shr32 returns a logical (unsigned) right shift of x by n bits.
fun shr32(x int, n int) int {
    ret (x >> n) & (mask32 >> n)
}

fun bigSigma0(x int) int { ret rotr32(x, 2)  ^ rotr32(x, 13) ^ rotr32(x, 22) }
fun bigSigma1(x int) int { ret rotr32(x, 6)  ^ rotr32(x, 11) ^ rotr32(x, 25) }
fun smlSigma0(x int) int { ret rotr32(x, 7)  ^ rotr32(x, 18) ^ shr32(x, 3) }
fun smlSigma1(x int) int { ret rotr32(x, 17) ^ rotr32(x, 19) ^ shr32(x, 10) }

fun ch(x int, y int, z int) int  { ret (x & y) ^ ((mask32 ^ x) & z) }
fun maj(x int, y int, z int) int { ret (x & y) ^ (x & z) ^ (y & z) }

// kRound returns the per-round constant K[i] for 0 <= i < 64. FIPS
// 180-4 §4.2.2 fractional cube-root values. Computed via a switch
// because volt doesn't yet have a package-level array literal that
// fits 64 entries cleanly.
fun kRound(i int) int {
    if i == 0  { ret 1116352408 }
    if i == 1  { ret 1899447441 }
    if i == 2  { ret 3049323471 }
    if i == 3  { ret 3921009573 }
    if i == 4  { ret 961987163  }
    if i == 5  { ret 1508970993 }
    if i == 6  { ret 2453635748 }
    if i == 7  { ret 2870763221 }
    if i == 8  { ret 3624381080 }
    if i == 9  { ret 310598401  }
    if i == 10 { ret 607225278  }
    if i == 11 { ret 1426881987 }
    if i == 12 { ret 1925078388 }
    if i == 13 { ret 2162078206 }
    if i == 14 { ret 2614888103 }
    if i == 15 { ret 3248222580 }
    if i == 16 { ret 3835390401 }
    if i == 17 { ret 4022224774 }
    if i == 18 { ret 264347078  }
    if i == 19 { ret 604807628  }
    if i == 20 { ret 770255983  }
    if i == 21 { ret 1249150122 }
    if i == 22 { ret 1555081692 }
    if i == 23 { ret 1996064986 }
    if i == 24 { ret 2554220882 }
    if i == 25 { ret 2821834349 }
    if i == 26 { ret 2952996808 }
    if i == 27 { ret 3210313671 }
    if i == 28 { ret 3336571891 }
    if i == 29 { ret 3584528711 }
    if i == 30 { ret 113926993  }
    if i == 31 { ret 338241895  }
    if i == 32 { ret 666307205  }
    if i == 33 { ret 773529912  }
    if i == 34 { ret 1294757372 }
    if i == 35 { ret 1396182291 }
    if i == 36 { ret 1695183700 }
    if i == 37 { ret 1986661051 }
    if i == 38 { ret 2177026350 }
    if i == 39 { ret 2456956037 }
    if i == 40 { ret 2730485921 }
    if i == 41 { ret 2820302411 }
    if i == 42 { ret 3259730800 }
    if i == 43 { ret 3345764771 }
    if i == 44 { ret 3516065817 }
    if i == 45 { ret 3600352804 }
    if i == 46 { ret 4094571909 }
    if i == 47 { ret 275423344  }
    if i == 48 { ret 430227734  }
    if i == 49 { ret 506948616  }
    if i == 50 { ret 659060556  }
    if i == 51 { ret 883997877  }
    if i == 52 { ret 958139571  }
    if i == 53 { ret 1322822218 }
    if i == 54 { ret 1537002063 }
    if i == 55 { ret 1747873779 }
    if i == 56 { ret 1955562222 }
    if i == 57 { ret 2024104815 }
    if i == 58 { ret 2227730452 }
    if i == 59 { ret 2361852424 }
    if i == 60 { ret 2428436474 }
    if i == 61 { ret 2756734187 }
    if i == 62 { ret 3204031479 }
    if i == 63 { ret 3329325298 }
    ret 0
}

// padded returns msg with the SHA-256 padding appended: a 0x80 byte,
// then enough zero bytes so the total length is 8 bytes short of a
// 64-byte multiple, then the original bit-length as a big-endian
// 64-bit integer.
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

// Sum returns the 32-byte SHA-256 digest of msg.
fun Sum(msg string) string {
    var p string = padded(msg)
    var blocks int = len(p) / 64

    // Initial hash values H[0..7] (FIPS §5.3.3).
    var h0 int = 1779033703
    var h1 int = 3144134277
    var h2 int = 1013904242
    var h3 int = 2773480762
    var h4 int = 1359893119
    var h5 int = 2600822924
    var h6 int = 528734635
    var h7 int = 1541459225

    var w []int = new(64) []int {}
    for b:=0; b < blocks; b++ {
        var base int = b * 64
        // W[0..15]: each 32-bit big-endian word from the block.
        for t:=0; t < 16; t++ {
            var idx int = base + t * 4
            var b0 int = p[idx]   & 255
            var b1 int = p[idx+1] & 255
            var b2 int = p[idx+2] & 255
            var b3 int = p[idx+3] & 255
            w[t] = ((b0 << 24) | (b1 << 16) | (b2 << 8) | b3) & mask32
        }
        // W[16..63]: σ1(W[t-2]) + W[t-7] + σ0(W[t-15]) + W[t-16].
        for t:=16; t < 64; t++ {
            var s0 int = smlSigma0(w[t-15])
            var s1 int = smlSigma1(w[t-2])
            w[t] = (s1 + w[t-7] + s0 + w[t-16]) & mask32
        }

        var a int = h0
        var bv int = h1
        var c int = h2
        var d int = h3
        var e int = h4
        var f int = h5
        var g int = h6
        var hv int = h7

        for t:=0; t < 64; t++ {
            var t1 int = (hv + bigSigma1(e) + ch(e, f, g) + kRound(t) + w[t]) & mask32
            var t2 int = (bigSigma0(a) + maj(a, bv, c)) & mask32
            hv = g
            g = f
            f = e
            e = (d + t1) & mask32
            d = c
            c = bv
            bv = a
            a = (t1 + t2) & mask32
        }

        h0 = (h0 + a)  & mask32
        h1 = (h1 + bv) & mask32
        h2 = (h2 + c)  & mask32
        h3 = (h3 + d)  & mask32
        h4 = (h4 + e)  & mask32
        h5 = (h5 + f)  & mask32
        h6 = (h6 + g)  & mask32
        h7 = (h7 + hv) & mask32
    }

    // Output H[0..7] as 32 bytes, big-endian.
    var out string = ""
    out = out + word32be(h0)
    out = out + word32be(h1)
    out = out + word32be(h2)
    out = out + word32be(h3)
    out = out + word32be(h4)
    out = out + word32be(h5)
    out = out + word32be(h6)
    out = out + word32be(h7)
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

// SumHex returns the 64-char lowercase-hex SHA-256 digest of msg.
// Uses bytes.Builder for O(n) assembly (n=64 here, but keeps the
// pattern consistent across the crypto-hash family).
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
