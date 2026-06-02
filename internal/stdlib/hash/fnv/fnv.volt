// Package fnv: Fowler–Noll–Vo non-cryptographic hash (variant 1a).
//
// FNV-1a is a tiny, fast hash that's good enough for hash tables,
// content-addressable IDs, change detection, and similar non-security
// uses. Two widths exported:
//
//	HashStr32(s string) int     — 32-bit FNV-1a of s's bytes
//	HashStr64(s string) int     — 64-bit FNV-1a of s's bytes
//
// Both return positive `int` (int64) values; for the 32-bit form the
// upper bits are zero.
//
// Constants from http://www.isthe.com/chongo/tech/comp/fnv/.

package fnv

fun Offset32() int { ret 2166136261 }
fun Prime32()  int { ret 16777619 }

fun Offset64() int { ret -3750763034362895579 }   // = 14695981039346656037 reinterpreted as int64
fun Prime64()  int { ret 1099511628211 }

// HashStr32 returns the 32-bit FNV-1a hash of the bytes of s.
//
// FNV-1a: hash = offset; for each byte b: hash = (hash XOR b) * prime.
// The 32-bit variant truncates to 32 bits after every multiply.
fun HashStr32(s string) int {
    var h int = Offset32()
    var mask int = 4294967295               // 0xFFFFFFFF
    var prime int = Prime32()
    var n int = len(s)
    for i:=0; i < n; i++ {
        var b int = s[i]
        h = (h ^ b) & mask
        h = (h * prime) & mask
    }
    ret h
}

// HashStr64 returns the 64-bit FNV-1a hash of the bytes of s. Since
// volt's int is 64 bits, no masking is needed — wraparound on
// multiplication matches the FNV-1a spec.
fun HashStr64(s string) int {
    var h int = Offset64()
    var prime int = Prime64()
    var n int = len(s)
    for i:=0; i < n; i++ {
        var b int = s[i]
        h = h ^ b
        h = h * prime
    }
    ret h
}

// HashInt32 returns the 32-bit FNV-1a hash of n's 8 little-endian
// bytes. Useful for bucketing ints (sharding by ID, hash-table
// keying by numeric column) without going through Itoa. Different
// from `HashStr32(strconv.Itoa(n))` — that hashes the textual
// representation, this hashes the binary 8-byte int directly.
fun HashInt32(n int) int {
    var h int = Offset32()
    var mask int = 4294967295
    var prime int = Prime32()
    var v int = n
    for i := 0; i < 8; i++ {
        var b int = v & 255
        h = (h ^ b) & mask
        h = (h * prime) & mask
        v = v / 256
    }
    ret h
}

// HashInt64 returns the 64-bit FNV-1a hash of n's 8 little-endian
// bytes. Volt's int is 64 bits, so no masking is needed.
fun HashInt64(n int) int {
    var h int = Offset64()
    var prime int = Prime64()
    var v int = n
    for i := 0; i < 8; i++ {
        var b int = v & 255
        h = h ^ b
        h = h * prime
        v = v / 256
    }
    ret h
}
