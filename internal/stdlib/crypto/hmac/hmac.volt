// Package hmac: HMAC-SHA256 message authentication (RFC 2104).
//
// Surface:
//   Sum256(key, msg string) string     — 32-byte binary HMAC tag
//   Sum256Hex(key, msg string) string  — 64-char lowercase hex tag
//
// Construction (RFC 2104 §2):
//   ipad = 0x36 byte repeated to block size (64 for SHA-256)
//   opad = 0x5C byte repeated
//   K'   = key, hashed down with SHA-256 if longer than block size,
//          then zero-padded out to block size
//   HMAC = SHA256( (K' XOR opad) || SHA256( (K' XOR ipad) || msg ) )

package hmac

import "crypto/sha256"
import "crypto/sha1"
import "crypto/md5"
import "bytes"

const blockSize int = 64

// normalizeKey256 returns a 64-byte key: hashes oversized keys down
// with SHA-256, then zero-pads to blockSize.
fun normalizeKey256(key string) string {
    var k string = key
    if len(k) > blockSize {
        k = sha256.Sum(k)
    }
    var pad int = blockSize - len(k)
    for i:=0; i < pad; i++ {
        k = k + chr(0)
    }
    ret k
}

// normalizeKey1 is the SHA-1 variant: oversized keys collapse via
// SHA-1 (20 bytes), then zero-pad to the 64-byte block size shared
// with SHA-256.
fun normalizeKey1(key string) string {
    var k string = key
    if len(k) > blockSize {
        k = sha1.Sum(k)
    }
    var pad int = blockSize - len(k)
    for i:=0; i < pad; i++ {
        k = k + chr(0)
    }
    ret k
}

// normalizeKeyMD5 is the MD5 variant: oversized keys collapse via
// MD5 (16 bytes), then zero-pad. MD5's natural block size is also
// 64 bytes — same as SHA-1/SHA-256.
fun normalizeKeyMD5(key string) string {
    var k string = key
    if len(k) > blockSize {
        k = md5.Sum(k)
    }
    var pad int = blockSize - len(k)
    for i:=0; i < pad; i++ {
        k = k + chr(0)
    }
    ret k
}

// xorPad XORs each byte of k with the constant `pad`. Both inputs
// are exactly blockSize bytes.
fun xorPad(k string, pad int) string {
    var out string = ""
    var n int = len(k)
    for i:=0; i < n; i++ {
        var b int = k[i] & 255
        out = out + chr((b ^ pad) & 255)
    }
    ret out
}

// Sum256 returns the 32-byte HMAC-SHA256 tag for (key, msg).
fun Sum256(key string, msg string) string {
    var k string = normalizeKey256(key)
    var inner string = sha256.Sum(xorPad(k, 54) + msg)   // 0x36 = 54
    ret sha256.Sum(xorPad(k, 92) + inner)                // 0x5C = 92
}

// Sum1 returns the 20-byte HMAC-SHA1 tag for (key, msg) per RFC 2202.
// Same ipad/opad construction as Sum256 — only the inner hash differs.
fun Sum1(key string, msg string) string {
    var k string = normalizeKey1(key)
    var inner string = sha1.Sum(xorPad(k, 54) + msg)
    ret sha1.Sum(xorPad(k, 92) + inner)
}

// SumMD5 returns the 16-byte HMAC-MD5 tag for (key, msg) per RFC 2104.
// Present for legacy interop (older auth schemes, S3 V2 signing, etc.).
fun SumMD5(key string, msg string) string {
    var k string = normalizeKeyMD5(key)
    var inner string = md5.Sum(xorPad(k, 54) + msg)
    ret md5.Sum(xorPad(k, 92) + inner)
}

// Sum256Hex returns the 64-char lowercase-hex HMAC-SHA256 tag.
fun Sum256Hex(key string, msg string) string {
    var d string = Sum256(key, msg)
    ret hexDigest(d)
}

// Sum1Hex returns the 40-char lowercase-hex HMAC-SHA1 tag.
fun Sum1Hex(key string, msg string) string {
    var d string = Sum1(key, msg)
    ret hexDigest(d)
}

// SumMD5Hex returns the 32-char lowercase-hex HMAC-MD5 tag.
fun SumMD5Hex(key string, msg string) string {
    var d string = SumMD5(key, msg)
    ret hexDigest(d)
}

// Equal reports whether a and b are byte-wise equal in
// CONSTANT TIME relative to their common length — i.e. the
// comparison loop does NOT short-circuit on the first mismatch.
// This matches the standard `hmac.Equal` Go API and guards
// against timing-side-channel attacks where an attacker measures
// the comparison latency to recover the prefix of a secret tag
// byte-by-byte. Different-length inputs always return false (and
// the cost-of-checking-length leak is considered acceptable —
// MAC tag lengths are public). Useful for: HMAC tag verification,
// session/CSRF-token comparison, password-equality checks (after
// hashing). DO NOT use plain `==` for any of those — it bails on
// the first mismatch and leaks timing.
fun Equal(a string, b string) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    var acc int = 0
    for i := 0; i < na; i++ {
        var x int = a[i] & 255
        var y int = b[i] & 255
        acc = acc | (x ^ y)
    }
    if acc == 0 { ret true }
    ret false
}

// hexDigest is the shared inline hex encoder for the *Hex helpers.
// O(n) via bytes.Builder (Pass 108).
fun hexDigest(d string) string {
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
