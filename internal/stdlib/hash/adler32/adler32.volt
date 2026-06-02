// Package adler32: Adler-32 checksum (RFC 1950 — zlib).
//
// Adler-32 is much faster than CRC-32 and produces a 32-bit
// checksum, but with weaker collision resistance — best for
// detecting accidental corruption (network, storage), not
// adversarial tampering.
//
// Surface:
//   Checksum(s string) int       — Adler-32 of the byte sequence
//
// Output is 32 bits packed as (b << 16) | a, returned as a
// non-negative int.

package adler32

// mod is the largest prime less than 2^16 — the Adler-32 modulus.
const mod int = 65521

// Checksum returns the Adler-32 checksum of s. Empty input returns 1.
// Algorithm: a starts at 1, b at 0; each byte adds a += s[i] and
// b += a (both mod 65521); final result is (b << 16) | a.
fun Checksum(s string) int {
    var a int = 1
    var b int = 0
    var n int = len(s)
    for i := 0; i < n; i++ {
        var v int = s[i] & 255
        a = (a + v) % mod
        b = (b + a) % mod
    }
    ret (b << 16) | a
}
