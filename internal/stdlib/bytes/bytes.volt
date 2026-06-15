// Package bytes: byte-slice utilities + an efficient string builder.
//
// volt strings are immutable byte sequences; building one via
// repeated `s + chr(b)` concat is O(n²). The Builder type
// accumulates bytes into a growable []byte and finalizes to a
// %string in O(n) via the runtime's volt_string_from_bytes intrinsic.

package bytes

import "syscall"
import "io"

// Builder grows a []byte buffer geometrically as bytes are appended,
// then converts the final contents to an immutable string in O(n).
type Builder struct {
    buf []byte
    n   int
}

fun NewBuilder() *Builder {
    var b *Builder = new Builder { buf: new(16) []byte {}, n: 0 }
    ret b
}

// NewBuilderSize constructs a Builder with an initial capacity hint
// of at least `cap` bytes. For workloads where the final size is
// predictable (e.g. concat of N known-length strings, base64 encoding),
// this avoids the geometric reallocation churn of repeated growTo.
// cap < 16 is rounded up to 16 (the default seed).
fun NewBuilderSize(cap int) *Builder {
    var c int = cap
    if c < 16 { c = 16 }
    var b *Builder = new Builder { buf: new(c) []byte {}, n: 0 }
    ret b
}

fun (b *Builder) Len() int { ret b.n }

// growTo ensures capacity is at least `need`. Doubles capacity each
// time so the amortized cost of WriteByte stays O(1). Pass 756 perf:
// if `need` is much larger than the doubled capacity (e.g. a huge
// WriteString into a fresh builder), allocate exactly `need` rather
// than wasting iterations in the inner doubling loop.
fun (b *Builder) growTo(need int) {
    if need <= len(b.buf) { ret }
    var newCap int = len(b.buf) * 2
    if newCap < 16 { newCap = 16 }
    if newCap < need { newCap = need }
    var nb []byte = new(newCap) []byte {}
    for i:=0; i < b.n; i++ {
        nb[i] = b.buf[i]
    }
    b.buf = nb
}

// WriteByte appends c to the buffer.
fun (b *Builder) WriteByte(c byte) {
    b.growTo(b.n + 1)
    b.buf[b.n] = c
    b.n = b.n + 1
}

// WriteString appends every byte of s to the buffer.
fun (b *Builder) WriteString(s string) {
    var sn int = len(s)
    b.growTo(b.n + sn)
    for i:=0; i < sn; i++ {
        b.buf[b.n + i] = s[i]
    }
    b.n = b.n + sn
}

// Write appends s and reports the bytes written, satisfying io.Writer so a
// *Builder can be used directly as an in-memory output sink (collect via
// io.Copy / exec.Cmd.Start, then read back with String()).
fun (b *Builder) Write(s string) (int, error) {
    b.WriteString(s)
    ret len(s), nil
}



// WriteBytes appends every byte of s to the buffer. Parallel to
// WriteString for []byte input.
fun (b *Builder) WriteBytes(s []byte) {
    var sn int = len(s)
    b.growTo(b.n + sn)
    for i:=0; i < sn; i++ {
        b.buf[b.n + i] = s[i]
    }
    b.n = b.n + sn
}

// WriteRepeat appends c repeated count times. count <= 0 is a no-op.
// Useful for padding / alignment fills / framing characters where
// the caller would otherwise loop with WriteByte.
fun (b *Builder) WriteRepeat(c byte, count int) {
    if count <= 0 { ret }
    b.growTo(b.n + count)
    for i := 0; i < count; i++ {
        b.buf[b.n + i] = c
    }
    b.n = b.n + count
}

// Bytes returns a fresh copy of the accumulated bytes as a []byte.
// The Builder retains its internal buffer (subsequent writes keep
// appending). Useful when downstream code needs []byte instead of
// the immutable %string that String() returns.
fun (b *Builder) Bytes() []byte {
    var out []byte = new(b.n) []byte {}
    for i:=0; i < b.n; i++ {
        out[i] = b.buf[i]
    }
    ret out
}

// Reset discards the accumulated bytes but keeps the buffer (so
// subsequent writes reuse the underlying allocation).
fun (b *Builder) Reset() { b.n = 0 }

// String materializes the buffer into an immutable string. O(n) —
// the underlying bytes are copied so the Builder can keep mutating
// without aliasing the result.
fun (b *Builder) String() string {
    ret syscall.BytesToString(b.buf, b.n)
}

// WriteBool appends `"true"` or `"false"` depending on v. Mirrors
// strconv.FormatBool semantics; useful for log-line / debug-string
// accumulation without the FormatBool + WriteString round trip.
fun (b *Builder) WriteBool(v bool) {
    if v {
        b.WriteString("true")
        ret
    }
    b.WriteString("false")
}

// WriteInt appends the base-10 decimal representation of n. Handles
// the full int64 range including negative values and MinInt (the
// only value whose absolute value isn't representable; we encode
// the digits via successive `n % 10` rounds before negating).
fun (b *Builder) WriteInt(n int) {
    if n == 0 {
        b.WriteByte(48)   // '0'
        ret
    }
    var neg bool = false
    if n < 0 {
        neg = true
        // Buffer the digits of |n| LSB-first. Compute against the
        // negative n so MinInt doesn't overflow on -n.
        var tmp []byte = new(20) []byte {}
        var nd int = 0
        for n != 0 {
            var d int = -(n % 10)   // 0..9 (n is negative, % yields ≤0)
            tmp[nd] = 48 + d
            nd = nd + 1
            n = n / 10
        }
        if neg { b.WriteByte(45) }  // '-'
        // Emit MSB-first.
        for i := nd - 1; i >= 0; i = i - 1 {
            b.WriteByte(tmp[i])
        }
        ret
    }
    var tmp []byte = new(20) []byte {}
    var nd int = 0
    for n != 0 {
        var d int = n % 10
        tmp[nd] = 48 + d
        nd = nd + 1
        n = n / 10
    }
    for i := nd - 1; i >= 0; i = i - 1 {
        b.WriteByte(tmp[i])
    }
}

// Equal reports whether two byte slices have the same length and
// the same bytes. Parallels strings.Equal for byte slices.
fun Equal(a []byte, b []byte) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    for i := 0; i < na; i++ {
        if a[i] != b[i] { ret false }
    }
    ret true
}

// HasPrefix reports whether s starts with prefix.
fun HasPrefix(s []byte, prefix []byte) bool {
    var ns int = len(s)
    var np int = len(prefix)
    if np > ns { ret false }
    for i := 0; i < np; i++ {
        if s[i] != prefix[i] { ret false }
    }
    ret true
}

// HasSuffix reports whether s ends with suffix.
fun HasSuffix(s []byte, suffix []byte) bool {
    var ns int = len(s)
    var nx int = len(suffix)
    if nx > ns { ret false }
    var off int = ns - nx
    for i := 0; i < nx; i++ {
        if s[off + i] != suffix[i] { ret false }
    }
    ret true
}

// Index returns the index of the first occurrence of sub in s, or -1
// if sub is not present. Naive O(n*m) scan; sufficient for small
// patterns (matches strings.Index).
fun Index(s []byte, sub []byte) int {
    var ns int = len(s)
    var nu int = len(sub)
    if nu == 0 { ret 0 }
    if nu > ns { ret -1 }
    var limit int = ns - nu + 1
    for i := 0; i < limit; i++ {
        var match bool = true
        for j := 0; j < nu; j++ {
            if s[i + j] != sub[j] { match = false; break }
        }
        if match { ret i }
    }
    ret -1
}

// Contains reports whether sub is a contiguous subslice of s.
fun Contains(s []byte, sub []byte) bool {
    ret Index(s, sub) >= 0
}

// IndexAfter returns the absolute index of the first occurrence of
// sub in s at or after byte position `from`, or -1 if absent. A
// negative `from` clamps to 0; `from > ns - nu` (i.e. too close to
// the end for sub to fit) returns -1. Empty sub returns `from`
// clamped to `len(s)`. Mirror of strings.IndexAfter — useful for
// "find next" iteration without slice churn.
fun IndexAfter(s []byte, sub []byte, from int) int {
    var ns int = len(s)
    var nu int = len(sub)
    if from < 0 { from = 0 }
    if nu == 0 {
        if from > ns { ret ns }
        ret from
    }
    if from > ns - nu { ret -1 }
    var limit int = ns - nu + 1
    for i := from; i < limit; i++ {
        var match bool = true
        for j := 0; j < nu; j++ {
            if s[i + j] != sub[j] { match = false; break }
        }
        if match { ret i }
    }
    ret -1
}

// ToLower returns a copy of s with every uppercase ASCII byte
// ('A'..'Z') folded to its lowercase counterpart. Non-letter bytes
// pass through unchanged. Parallels strings.ToLower for []byte.
fun ToLower(s []byte) []byte {
    var n int = len(s)
    var out []byte = new(n) []byte {}
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 65 {
            if c <= 90 {
                out[i] = c + 32
            } else {
                out[i] = c
            }
        } else {
            out[i] = c
        }
    }
    ret out
}

// ToUpper returns a copy of s with every lowercase ASCII byte
// ('a'..'z') folded to its uppercase counterpart.
fun ToUpper(s []byte) []byte {
    var n int = len(s)
    var out []byte = new(n) []byte {}
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 97 {
            if c <= 122 {
                out[i] = c - 32
            } else {
                out[i] = c
            }
        } else {
            out[i] = c
        }
    }
    ret out
}

// Repeat returns a new byte slice consisting of `count` copies of b.
// Negative or zero count returns an empty slice (matches strings.Repeat).
fun Repeat(b []byte, count int) []byte {
    if count <= 0 {
        var empty []byte = new(0) []byte {}
        ret empty
    }
    var n int = len(b)
    var total int = n * count
    var out []byte = new(total) []byte {}
    for c := 0; c < count; c++ {
        var off int = c * n
        for i := 0; i < n; i++ {
            out[off + i] = b[i]
        }
    }
    ret out
}

// TrimSpace returns a sub-slice of s with leading + trailing
// Go-style whitespace bytes removed (space / tab / newline / CR /
// VT / FF). The returned slice is a fresh allocation — volt slices
// move on use, so we copy the surviving bytes rather than reslicing.
fun TrimSpace(s []byte) []byte {
    var n int = len(s)
    var lo int = 0
    for lo < n {
        var c byte = s[lo]
        var done bool = true
        if c == 32 { done = false } else
        if c == 9  { done = false } else
        if c == 10 { done = false } else
        if c == 13 { done = false } else
        if c == 11 { done = false } else
        if c == 12 { done = false }
        if done { break }
        lo = lo + 1
    }
    var hi int = n
    for hi > lo {
        var c byte = s[hi - 1]
        var done bool = true
        if c == 32 { done = false } else
        if c == 9  { done = false } else
        if c == 10 { done = false } else
        if c == 13 { done = false } else
        if c == 11 { done = false } else
        if c == 12 { done = false }
        if done { break }
        hi = hi - 1
    }
    var out []byte = new(hi - lo) []byte {}
    var k int = 0
    for i := lo; i < hi; i++ {
        out[k] = s[i]
        k = k + 1
    }
    ret out
}

// TrimNewline returns s with a single trailing newline removed —
// strips `\r\n`, `\n`, or `\r` (in that priority order), or returns
// a copy of s unchanged otherwise. Byte-slice mirror of
// strings.TrimNewline (chomp-style). Allocates a fresh slice for the
// trimmed result — volt slices move on use, so we cannot reslice.
fun TrimNewline(s []byte) []byte {
    var n int = len(s)
    var end int = n
    if n >= 2 {
        if s[n-2] == 13 {
            if s[n-1] == 10 { end = n - 2 }
        }
    }
    if end == n {
        if n >= 1 {
            if s[n-1] == 10 { end = n - 1 }
            if s[n-1] == 13 { end = n - 1 }
        }
    }
    var out []byte = new(end) []byte {}
    for i := 0; i < end; i++ {
        out[i] = s[i]
    }
    ret out
}

// Slice returns the sub-slice s[lo:hi] by BYTE index with bounds
// clamping: lo < 0 → 0, hi > len(s) → len(s), hi <= lo → empty
// []byte. Volt slices move on use, so this allocates a fresh copy
// of the chosen range. The natural primitive for sub-extraction
// when the byte offsets came from Index / IndexAfter / Cut output.
// Byte-slice mirror of strings.Slice.
fun Slice(s []byte, lo int, hi int) []byte {
    var n int = len(s)
    if lo < 0 { lo = 0 }
    if hi > n { hi = n }
    if hi <= lo {
        var empty []byte = new(0) []byte {}
        ret empty
    }
    var out []byte = new(hi - lo) []byte {}
    for i := lo; i < hi; i++ {
        out[i - lo] = s[i]
    }
    ret out
}

// Left returns the first n bytes of s as a fresh []byte. n <= 0
// returns empty; n >= len(s) returns a full copy of s. Byte-slice
// mirror of strings.Left.
fun Left(s []byte, n int) []byte {
    if n <= 0 { ret new(0) []byte {} }
    var sn int = len(s)
    if n >= sn {
        var out []byte = new(sn) []byte {}
        for i := 0; i < sn; i++ { out[i] = s[i] }
        ret out
    }
    ret Slice(s, 0, n)
}

// Right returns the last n bytes of s as a fresh []byte. n <= 0
// returns empty; n >= len(s) returns a full copy of s. Byte-slice
// mirror of strings.Right.
fun Right(s []byte, n int) []byte {
    if n <= 0 { ret new(0) []byte {} }
    var sn int = len(s)
    if n >= sn {
        var out []byte = new(sn) []byte {}
        for i := 0; i < sn; i++ { out[i] = s[i] }
        ret out
    }
    ret Slice(s, sn - n, sn)
}

// PadLeft returns a fresh []byte left-padded with byte c so the
// total length is at least n. If len(s) >= n, returns a copy of s
// unchanged. Byte-slice mirror of strings.PadLeft. Useful for
// fixed-width binary record output, column alignment in raw
// byte-stream contexts.
fun PadLeft(s []byte, n int, c byte) []byte {
    var sn int = len(s)
    if sn >= n {
        var out []byte = new(sn) []byte {}
        for i := 0; i < sn; i++ { out[i] = s[i] }
        ret out
    }
    var pad int = n - sn
    var out []byte = new(n) []byte {}
    for i := 0; i < pad; i++ { out[i] = c }
    for i := 0; i < sn; i++ { out[pad + i] = s[i] }
    ret out
}

// PadRight returns a fresh []byte right-padded with byte c so the
// total length is at least n. If len(s) >= n, returns a copy of s
// unchanged. Byte-slice mirror of strings.PadRight.
fun PadRight(s []byte, n int, c byte) []byte {
    var sn int = len(s)
    if sn >= n {
        var out []byte = new(sn) []byte {}
        for i := 0; i < sn; i++ { out[i] = s[i] }
        ret out
    }
    var out []byte = new(n) []byte {}
    for i := 0; i < sn; i++ { out[i] = s[i] }
    for i := sn; i < n; i++ { out[i] = c }
    ret out
}

// Center returns a fresh []byte symmetrically padded with byte c so
// the total length is at least n. When the padding is odd the EXTRA
// byte goes on the right (matches Python str.center / strings.Center).
// If len(s) >= n, returns a copy of s unchanged. Byte-slice mirror of
// strings.Center.
fun Center(s []byte, n int, c byte) []byte {
    var sn int = len(s)
    if sn >= n {
        var out []byte = new(sn) []byte {}
        for i := 0; i < sn; i++ { out[i] = s[i] }
        ret out
    }
    var total int = n - sn
    var left int = total / 2
    var right int = total - left
    var out []byte = new(n) []byte {}
    for i := 0; i < left; i++ { out[i] = c }
    for i := 0; i < sn; i++ { out[left + i] = s[i] }
    for i := 0; i < right; i++ { out[left + sn + i] = c }
    ret out
}

// LongestRunFunc returns the length of the longest run of consecutive
// bytes for which `pred(b)` returns true. 0 if no byte matches.
// Byte-slice mirror of strings.LongestRunFunc — useful for "longest
// printable run", "longest letter run", "longest non-NUL run" on
// `[]byte` payloads.
fun LongestRunFunc(s []byte, pred fun(byte) bool) int {
    var n int = len(s)
    var best int = 0
    var cur int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) {
            cur = cur + 1
            if cur > best { best = cur }
        } else {
            cur = 0
        }
    }
    ret best
}

// LongestRun returns the length of the longest run of consecutive
// `c` bytes in s. 0 if absent or s is empty. Byte-slice mirror of
// strings.LongestRun. Useful for indent-depth estimation, repeated-
// byte detection on `[]byte` payloads (e.g. longest `\0` run in a
// binary stream, longest separator-byte run in a frame).
fun LongestRun(s []byte, c byte) int {
    var n int = len(s)
    var best int = 0
    var cur int = 0
    for i := 0; i < n; i++ {
        if s[i] == c {
            cur = cur + 1
            if cur > best { best = cur }
        } else {
            cur = 0
        }
    }
    ret best
}

// OnlyAscii returns a fresh []byte with every byte ≥ 128 removed
// from s. Keeps the 0..127 range (including controls). Byte-slice
// mirror of strings.OnlyAscii. Two-pass: count survivors then
// allocate exact-size + copy. Useful for ASCII-safe rendering of
// `[]byte` payloads without round-tripping through `bytes.String(b)`.
fun OnlyAscii(s []byte) []byte {
    var n int = len(s)
    var keep int = 0
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if c < 128 { keep = keep + 1 }
    }
    var out []byte = new(keep) []byte {}
    var k int = 0
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if c < 128 {
            out[k] = s[i]
            k = k + 1
        }
    }
    ret out
}

// IsAsciiPrintable reports whether every byte of s is in the
// printable-ASCII range 0x20..0x7E (space through `~`). Empty
// input returns true (vacuous). Stricter than IsAscii — control
// characters and DEL (0x7F) fail. Byte-slice mirror of
// strings.IsAsciiPrintable. Useful for "can this be displayed
// without escapes?" checks on `[]byte` payloads.
fun IsAsciiPrintable(s []byte) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if c < 32 { ret false }
        if c > 126 { ret false }
    }
    ret true
}

// IsNumeric reports whether every byte of s is an ASCII decimal
// digit ('0'..'9'). Empty input returns false — matching
// strings.IsNumeric semantics ("requires at least one digit").
// Useful for "is this byte slice a positive integer string?" guards
// on network / file input where round-tripping through
// bytes.String(b) + Atoi would allocate.
fun IsNumeric(s []byte) bool {
    var n int = len(s)
    if n == 0 { ret false }
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c < 48 { ret false }
        if c > 57 { ret false }
    }
    ret true
}

// IsAlpha reports whether every byte of s is an ASCII letter
// ('A'..'Z' or 'a'..'z'). Empty input returns false.
// Byte-slice mirror of strings.IsAlpha.
fun IsAlpha(s []byte) bool {
    var n int = len(s)
    if n == 0 { ret false }
    for i := 0; i < n; i++ {
        var c byte = s[i]
        var ok bool = false
        if c >= 65 {
            if c <= 90 { ok = true }
        }
        if c >= 97 {
            if c <= 122 { ok = true }
        }
        if !ok { ret false }
    }
    ret true
}

// IsAlphanumeric reports whether every byte of s is an ASCII letter
// or digit. Empty input returns false. Byte-slice mirror of
// strings.IsAlphanumeric.
fun IsAlphanumeric(s []byte) bool {
    var n int = len(s)
    if n == 0 { ret false }
    for i := 0; i < n; i++ {
        var c byte = s[i]
        var ok bool = false
        if c >= 48 { if c <= 57  { ok = true } }
        if c >= 65 { if c <= 90  { ok = true } }
        if c >= 97 { if c <= 122 { ok = true } }
        if !ok { ret false }
    }
    ret true
}

// SortBytes returns a fresh []byte with the elements of s in
// ascending byte order. Counting sort over the 256-bucket histogram
// (O(n + 256)) — faster than a comparison sort and trivially stable.
// Byte-slice mirror of strings.SortChars. Useful for: anagram-key
// generation, frequency normalization, hash-bucket keying on []byte
// payloads.
fun SortBytes(s []byte) []byte {
    var n int = len(s)
    if n == 0 {
        var empty []byte = new(0) []byte {}
        ret empty
    }
    var hist []int = new(256) []int {}
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        hist[c] = hist[c] + 1
    }
    var out []byte = new(n) []byte {}
    var off int = 0
    for k := 0; k < 256; k++ {
        var c int = hist[k]
        var kb byte = k
        for j := 0; j < c; j++ {
            out[off] = kb
            off = off + 1
        }
    }
    ret out
}

// IsBlank reports whether s contains only Go-style whitespace bytes
// (space / tab / newline / CR / VT / FF). Empty input returns true
// (no non-whitespace bytes). Byte-slice mirror of strings.IsBlank —
// useful for "is this line meaningful?" checks on buffered file /
// network input where the payload is `[]byte`.
fun IsBlank(s []byte) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        var c byte = s[i]
        var ws bool = false
        if c == 32 { ws = true } else
        if c == 9  { ws = true } else
        if c == 10 { ws = true } else
        if c == 13 { ws = true } else
        if c == 11 { ws = true } else
        if c == 12 { ws = true }
        if !ws { ret false }
    }
    ret true
}

// TrimPrefix returns s without the leading prefix. If s doesn't
// start with prefix, returns a copy of s unchanged. Mirrors
// strings.TrimPrefix for []byte.
fun TrimPrefix(s []byte, prefix []byte) []byte {
    if !HasPrefix(s, prefix) {
        var n int = len(s)
        var out []byte = new(n) []byte {}
        for i := 0; i < n; i++ { out[i] = s[i] }
        ret out
    }
    var ns int = len(s)
    var np int = len(prefix)
    var out []byte = new(ns - np) []byte {}
    var k int = 0
    for i := np; i < ns; i++ {
        out[k] = s[i]
        k = k + 1
    }
    ret out
}

// TrimSuffix returns s without the trailing suffix. If s doesn't
// end with suffix, returns a copy of s unchanged.
fun TrimSuffix(s []byte, suffix []byte) []byte {
    if !HasSuffix(s, suffix) {
        var n int = len(s)
        var out []byte = new(n) []byte {}
        for i := 0; i < n; i++ { out[i] = s[i] }
        ret out
    }
    var ns int = len(s)
    var nx int = len(suffix)
    var hi int = ns - nx
    var out []byte = new(hi) []byte {}
    for i := 0; i < hi; i++ { out[i] = s[i] }
    ret out
}

// Split slices s into all subslices separated by sep, returning a
// slice of those subslices. If sep is empty, Split returns a slice
// of length 1 containing the input. If sep is not found in s, the
// result is one element: s. Matches Go's bytes.Split surface.
fun Split(s []byte, sep []byte) [][]byte {
    var out [][]byte = new(0) [][]byte {}
    var n int = len(s)
    var nsep int = len(sep)
    // Empty separator: degenerate (Go splits into per-byte slices,
    // but our simpler convention returns the single input slice
    // to avoid surprising heap blow-up on long inputs).
    if nsep == 0 {
        var only []byte = new(n) []byte {}
        for i := 0; i < n; i++ { only[i] = s[i] }
        out = append(out, only)
        ret out
    }
    var start int = 0
    var i int = 0
    var limit int = n - nsep
    for i <= limit {
        var match bool = true
        for j := 0; j < nsep; j++ {
            if s[i+j] != sep[j] { match = false; break }
        }
        if match {
            var piece []byte = new(i - start) []byte {}
            for k := start; k < i; k++ {
                piece[k - start] = s[k]
            }
            out = append(out, piece)
            i = i + nsep
            start = i
        } else {
            i = i + 1
        }
    }
    var tail []byte = new(n - start) []byte {}
    for k := start; k < n; k++ {
        tail[k - start] = s[k]
    }
    out = append(out, tail)
    ret out
}

// Join concatenates the elements of parts, separating them by sep,
// and returns a fresh []byte. Empty parts yields an empty slice.
fun Join(parts [][]byte, sep []byte) []byte {
    var np int = len(parts)
    if np == 0 {
        var empty []byte = new(0) []byte {}
        ret empty
    }
    var nsep int = len(sep)
    var total int = 0
    for i := 0; i < np; i++ {
        total = total + len(parts[i])
    }
    if np > 1 {
        total = total + nsep * (np - 1)
    }
    var out []byte = new(total) []byte {}
    var pos int = 0
    for i := 0; i < np; i++ {
        if i > 0 {
            for k := 0; k < nsep; k++ {
                out[pos] = sep[k]
                pos = pos + 1
            }
        }
        var pl int = len(parts[i])
        for k := 0; k < pl; k++ {
            out[pos] = parts[i][k]
            pos = pos + 1
        }
    }
    ret out
}

// Count returns the number of non-overlapping occurrences of sep in
// s. Matches Go's bytes.Count surface — sep == "" / empty would
// return len(s)+1 in Go, but we return 0 here to avoid the
// surprising rune-vs-byte distinction.
fun Count(s []byte, sep []byte) int {
    var n int = len(s)
    var nsep int = len(sep)
    if nsep == 0 { ret 0 }
    if nsep > n { ret 0 }
    var c int = 0
    var i int = 0
    var limit int = n - nsep
    for i <= limit {
        var match bool = true
        for j := 0; j < nsep; j++ {
            if s[i+j] != sep[j] { match = false; break }
        }
        if match {
            c = c + 1
            i = i + nsep   // non-overlapping
        } else {
            i = i + 1
        }
    }
    ret c
}

// CountByte returns the number of times byte c appears in s.
// Single-byte fast path; avoids the substring-build overhead of
// `Count(s, []byte{c})`. Byte-slice counterpart to strings.CountByte.
fun CountByte(s []byte, c byte) int {
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        if s[i] == c { k = k + 1 }
    }
    ret k
}

// CountFunc returns the number of bytes in s for which pred returns
// true. Byte-slice counterpart to strings.CountFunc. Predicate-driven
// — useful for ad-hoc tallies (digits, control bytes, custom-class)
// without pre-building a chars-set slice. Empty s returns 0.
fun CountFunc(s []byte, pred fun(byte) bool) int {
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        if pred(s[i]) { k = k + 1 }
    }
    ret k
}

// Fields splits s around each run of one or more Go-style whitespace
// bytes (space / tab / newline / CR / VT / FF) into a [][]byte.
// Adjacent whitespace runs collapse — Fields never returns empty
// pieces. Empty or all-whitespace input returns an empty slice.
fun Fields(s []byte) [][]byte {
    var out [][]byte = new(0) [][]byte {}
    var n int = len(s)
    var start int = 0
    var inField bool = false
    for i := 0; i < n; i++ {
        var c byte = s[i]
        var isWs bool = false
        if c == 32 { isWs = true } else
        if c == 9  { isWs = true } else
        if c == 10 { isWs = true } else
        if c == 13 { isWs = true } else
        if c == 11 { isWs = true } else
        if c == 12 { isWs = true }
        if isWs {
            if inField {
                var piece []byte = new(i - start) []byte {}
                for k := start; k < i; k++ {
                    piece[k - start] = s[k]
                }
                out = append(out, piece)
                inField = false
            }
        } else {
            if !inField {
                start = i
                inField = true
            }
        }
    }
    if inField {
        var piece []byte = new(n - start) []byte {}
        for k := start; k < n; k++ {
            piece[k - start] = s[k]
        }
        out = append(out, piece)
    }
    ret out
}

// Lines splits s into lines on `\n` and strips a single trailing
// `\r` from each line (handles both LF and CRLF). Mirrors
// strings.Lines for the []byte case. Empty input returns an empty
// slice. A trailing newline does not produce a final empty line.
fun Lines(s []byte) [][]byte {
    var n int = len(s)
    var out [][]byte = new(0) [][]byte {}
    if n == 0 { ret out }
    var start int = 0
    for i := 0; i < n; i++ {
        if s[i] == 10 {                       // '\n'
            var end int = i
            if end > start {
                if s[end - 1] == 13 { end = end - 1 }   // strip '\r'
            }
            var piece []byte = new(end - start) []byte {}
            for k := start; k < end; k++ {
                piece[k - start] = s[k]
            }
            out = append(out, piece)
            start = i + 1
        }
    }
    if start < n {
        var end int = n
        if s[end - 1] == 13 { end = end - 1 }
        var piece []byte = new(end - start) []byte {}
        for k := start; k < end; k++ {
            piece[k - start] = s[k]
        }
        out = append(out, piece)
    }
    ret out
}

// HeadLines returns the first n lines of s (split on '\n',
// \r-aware) rejoined with '\n' into a fresh []byte. n<=0 → empty;
// n >= line-count → all of s with normalized newlines. Byte-slice
// mirror of strings.HeadLines.
fun HeadLines(s []byte, n int) []byte {
    if n <= 0 { ret new(0) []byte {} }
    var ls [][]byte = Lines(s)
    var nl int = len(ls)
    if n > nl { n = nl }
    if n == 0 { ret new(0) []byte {} }
    var out []byte = new(0) []byte {}
    for i := 0; i < n; i++ {
        var line []byte = ls[i]
        var ln int = len(line)
        for k := 0; k < ln; k++ { out = append(out, line[k]) }
        if i < n - 1 { out = append(out, 10) }
    }
    ret out
}

// TailLines returns the last n lines of s as a fresh []byte. n<=0
// → empty; n >= line-count → all. Byte-slice mirror of
// strings.TailLines.
fun TailLines(s []byte, n int) []byte {
    if n <= 0 { ret new(0) []byte {} }
    var ls [][]byte = Lines(s)
    var nl int = len(ls)
    if n > nl { n = nl }
    if n == 0 { ret new(0) []byte {} }
    var off int = nl - n
    var out []byte = new(0) []byte {}
    for i := 0; i < n; i++ {
        var line []byte = ls[off + i]
        var ln int = len(line)
        for k := 0; k < ln; k++ { out = append(out, line[k]) }
        if i < n - 1 { out = append(out, 10) }
    }
    ret out
}

// Hexdump returns a classic xxd-style hex dump of s: 16 bytes per
// row with 8-digit offset, two 8-byte hex groups separated by
// extra space, and ASCII column (non-printables shown as '.').
// Byte-slice mirror of strings.Hexdump. Empty s returns "".
fun Hexdump(s []byte) string {
    var n int = len(s)
    if n == 0 { ret "" }
    var b *Builder = NewBuilder()
    var off int = 0
    for off < n {
        b.WriteString(hd_FormatHexPad8(off))
        b.WriteString("  ")
        for i := 0; i < 16; i++ {
            if off + i < n {
                var by int = s[off + i] & 255
                b.WriteString(hd_FormatHexPad2(by))
            } else {
                b.WriteString("  ")
            }
            if i == 7 { b.WriteString("  ") } else { b.WriteByte(32) }
        }
        b.WriteString(" |")
        for i := 0; i < 16; i++ {
            if off + i < n {
                var c int = s[off + i] & 255
                if c < 32 {
                    b.WriteByte(46)
                } else {
                    if c > 126 {
                        b.WriteByte(46)
                    } else {
                        b.WriteByte(s[off + i])
                    }
                }
            }
        }
        b.WriteByte(124)
        if off + 16 < n { b.WriteByte(10) }
        off = off + 16
    }
    ret b.String()
}

// hd_FormatHexPad2 — 2-digit zero-padded lowercase hex for Hexdump.
fun hd_FormatHexPad2(n int) string {
    var hi int = (n >> 4) & 15
    var lo int = n & 15
    var b *Builder = NewBuilder()
    b.WriteByte(hd_hexNibbleByte(hi))
    b.WriteByte(hd_hexNibbleByte(lo))
    ret b.String()
}

// hd_FormatHexPad8 — 8-digit zero-padded lowercase hex for offset col.
fun hd_FormatHexPad8(n int) string {
    var b *Builder = NewBuilder()
    for i := 7; i >= 0; i-- {
        var nib int = (n >> (i * 4)) & 15
        b.WriteByte(hd_hexNibbleByte(nib))
    }
    ret b.String()
}

// hd_hexNibbleByte — 0..15 → '0'..'9','a'..'f'.
fun hd_hexNibbleByte(n int) byte {
    if n < 10 { ret ((48 + n) & 255) }
    ret ((87 + n) & 255)
}

// FieldsFunc splits s at every byte where fn returns true. Runs of
// separator bytes collapse (no empty pieces in the result),
// matching the semantics of Fields generalized to a predicate.
// Empty input or all-separator input returns an empty slice. Byte-
// slice mirror of strings.FieldsFunc — useful for multi-set
// separators on []byte payloads, or splitting at digit / non-digit
// boundaries.
fun FieldsFunc(s []byte, fn fun(byte) bool) [][]byte {
    var out [][]byte = new(0) [][]byte {}
    var n int = len(s)
    var start int = 0
    var inField bool = false
    for i := 0; i < n; i++ {
        if fn(s[i]) {
            if inField {
                var piece []byte = new(i - start) []byte {}
                for k := start; k < i; k++ {
                    piece[k - start] = s[k]
                }
                out = append(out, piece)
                inField = false
            }
        } else {
            if !inField {
                start = i
                inField = true
            }
        }
    }
    if inField {
        var piece []byte = new(n - start) []byte {}
        for k := start; k < n; k++ {
            piece[k - start] = s[k]
        }
        out = append(out, piece)
    }
    ret out
}

// IndexByte returns the index of the first occurrence of c in s, or
// -1 if c is not present. O(n) linear scan.
fun IndexByte(s []byte, c byte) int {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if s[i] == c { ret i }
    }
    ret -1
}

// IndexByteAfter returns the absolute index of the first occurrence
// of byte c at or after position `from` in s, or -1 if absent.
// Negative `from` clamps to 0; `from >= len(s)` returns -1. Byte-
// slice mirror of strings.IndexByteAfter — useful for "find the next
// delimiter after position N" idioms on `[]byte` payloads.
fun IndexByteAfter(s []byte, c byte, from int) int {
    var n int = len(s)
    if from < 0 { from = 0 }
    if from >= n { ret -1 }
    for i := from; i < n; i++ {
        if s[i] == c { ret i }
    }
    ret -1
}

// LastIndexByte returns the index of the last occurrence of c in s,
// or -1 if c is not present.
fun LastIndexByte(s []byte, c byte) int {
    for i := len(s) - 1; i >= 0; i = i - 1 {
        if s[i] == c { ret i }
    }
    ret -1
}

// LastIndex returns the index of the last occurrence of sep in s,
// or -1 if sep is not present. Empty sep returns len(s) (matches
// Go's strings.LastIndex / bytes.LastIndex semantics).
fun LastIndex(s []byte, sep []byte) int {
    var n int = len(s)
    var nsep int = len(sep)
    if nsep == 0 { ret n }
    if nsep > n { ret -1 }
    for i := n - nsep; i >= 0; i = i - 1 {
        var match bool = true
        for j := 0; j < nsep; j++ {
            if s[i+j] != sep[j] { match = false; break }
        }
        if match { ret i }
    }
    ret -1
}

// Map returns a new byte slice with fn applied to every byte of s.
// Parallel to strings.Map for byte slices.
fun Map(fn fun(byte) byte, s []byte) []byte {
    var n int = len(s)
    var out []byte = new(n) []byte {}
    for i := 0; i < n; i++ {
        out[i] = fn(s[i])
    }
    ret out
}

// Replace returns a new byte slice with each occurrence of old in s
// replaced by repl. Empty old returns a copy of s unchanged.
// Matches Go's bytes.Replace surface (without the -1/count parameter
// — replace-all is the default and only mode).
fun Replace(s []byte, old []byte, repl []byte) []byte {
    var lold int = len(old)
    if lold == 0 {
        var n int = len(s)
        var out []byte = new(n) []byte {}
        for i := 0; i < n; i++ { out[i] = s[i] }
        ret out
    }
    var n int = len(s)
    var lrepl int = len(repl)
    // Count matches in a first pass so we can size the output exactly.
    var matches int = 0
    var i int = 0
    var last int = n - lold
    for i <= last {
        var match bool = true
        for j := 0; j < lold; j++ {
            if s[i + j] != old[j] { match = false; break }
        }
        if match {
            matches = matches + 1
            i = i + lold
        } else {
            i = i + 1
        }
    }
    if matches == 0 {
        var out []byte = new(n) []byte {}
        for k := 0; k < n; k++ { out[k] = s[k] }
        ret out
    }
    var total int = n + matches * (lrepl - lold)
    var out []byte = new(total) []byte {}
    var src int = 0
    var dst int = 0
    for src <= last {
        var match bool = true
        for j := 0; j < lold; j++ {
            if s[src + j] != old[j] { match = false; break }
        }
        if match {
            for k := 0; k < lrepl; k++ {
                out[dst] = repl[k]
                dst = dst + 1
            }
            src = src + lold
        } else {
            out[dst] = s[src]
            dst = dst + 1
            src = src + 1
        }
    }
    for src < n {
        out[dst] = s[src]
        dst = dst + 1
        src = src + 1
    }
    ret out
}

// IndexAny returns the index of the first byte in s that appears in
// chars, or -1 if no byte from chars is present. Empty chars
// returns -1 (no candidate bytes to match).
fun IndexAny(s []byte, chars []byte) int {
    var n int = len(s)
    var nc int = len(chars)
    if nc == 0 { ret -1 }
    for i := 0; i < n; i++ {
        for j := 0; j < nc; j++ {
            if s[i] == chars[j] { ret i }
        }
    }
    ret -1
}

// ContainsAny reports whether any byte in chars occurs in s.
fun ContainsAny(s []byte, chars []byte) bool {
    ret IndexAny(s, chars) >= 0
}

// CountAny returns the total number of bytes in s that match ANY
// byte in chars. O(len(s) + len(chars)) via a 256-byte membership
// lookup. Byte-slice mirror of strings.CountAny. Empty chars → 0.
// Useful for tallying multiple bytes at once on `[]byte` payloads
// (digit count in a token, control-byte count in a frame).
// HasOnly reports whether every byte of s appears in the chars
// set (i.e. s is drawn only from the alphabet defined by chars).
// Byte-slice mirror of strings.HasOnly. Empty s → true (vacuous);
// empty chars + non-empty s → false. O(len(s) + len(chars)) via a
// 256-byte membership lookup. Useful for whitelist validation on
// byte buffers — "is this payload drawn only from my allowed
// alphabet?" guards.
fun HasOnly(s []byte, chars []byte) bool {
    var n int = len(s)
    if n == 0 { ret true }
    if len(chars) == 0 { ret false }
    var member []bool = new(256) []bool {}
    var cn int = len(chars)
    for i := 0; i < cn; i++ {
        var c int = chars[i] & 255
        member[c] = true
    }
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if !member[c] { ret false }
    }
    ret true
}

// HasNone reports whether no byte of s appears in the chars set
// (i.e. s is free of every byte in the blacklist). Byte-slice
// mirror of strings.HasNone. Empty s returns true (vacuous);
// empty chars returns true (nothing forbidden). O(len(s) +
// len(chars)) via a 256-byte membership lookup. Useful for
// blacklist screens over byte buffers — "this payload contains
// no forbidden bytes" guards (control-char sanitizers, etc.).
fun HasNone(s []byte, chars []byte) bool {
    var n int = len(s)
    if n == 0 { ret true }
    var cn int = len(chars)
    if cn == 0 { ret true }
    var member []bool = new(256) []bool {}
    for i := 0; i < cn; i++ {
        var c int = chars[i] & 255
        member[c] = true
    }
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if member[c] { ret false }
    }
    ret true
}

fun CountAny(s []byte, chars []byte) int {
    var cn int = len(chars)
    if cn == 0 { ret 0 }
    var member []bool = new(256) []bool {}
    for i := 0; i < cn; i++ {
        var c int = chars[i] & 255
        member[c] = true
    }
    var n int = len(s)
    var k int = 0
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if member[c] { k = k + 1 }
    }
    ret k
}

// LastIndexAny returns the index of the last byte in s that appears
// in chars, or -1 if none. Empty chars returns -1. Mirrors
// strings.LastIndexAny — useful for "find rightmost separator / ANY
// of these terminators / etc.".
fun LastIndexAny(s []byte, chars []byte) int {
    var n int = len(s)
    var nc int = len(chars)
    if nc == 0 { ret -1 }
    for i := n - 1; i >= 0; i-- {
        for j := 0; j < nc; j++ {
            if s[i] == chars[j] { ret i }
        }
    }
    ret -1
}

// bytesCutsetContains reports whether b appears in cutset.
fun bytesCutsetContains(cutset []byte, b byte) bool {
    var n int = len(cutset)
    for i := 0; i < n; i++ {
        if cutset[i] == b { ret true }
    }
    ret false
}

// TrimLeft returns a copy of s with all leading bytes that appear
// in cutset removed.
fun TrimLeft(s []byte, cutset []byte) []byte {
    var n int = len(s)
    var lo int = 0
    for lo < n {
        if !bytesCutsetContains(cutset, s[lo]) { break }
        lo = lo + 1
    }
    var out []byte = new(n - lo) []byte {}
    for i := lo; i < n; i++ {
        out[i - lo] = s[i]
    }
    ret out
}

// TrimRight returns a copy of s with all trailing bytes that appear
// in cutset removed.
fun TrimRight(s []byte, cutset []byte) []byte {
    var n int = len(s)
    var hi int = n
    for hi > 0 {
        if !bytesCutsetContains(cutset, s[hi - 1]) { break }
        hi = hi - 1
    }
    var out []byte = new(hi) []byte {}
    for i := 0; i < hi; i++ {
        out[i] = s[i]
    }
    ret out
}

// Trim returns a copy of s with all leading and trailing bytes that
// appear in cutset removed. Empty cutset returns a copy unchanged.
fun Trim(s []byte, cutset []byte) []byte {
    var n int = len(s)
    if len(cutset) == 0 {
        var out []byte = new(n) []byte {}
        for i := 0; i < n; i++ { out[i] = s[i] }
        ret out
    }
    var lo int = 0
    for lo < n {
        if !bytesCutsetContains(cutset, s[lo]) { break }
        lo = lo + 1
    }
    var hi int = n
    for hi > lo {
        if !bytesCutsetContains(cutset, s[hi - 1]) { break }
        hi = hi - 1
    }
    var out []byte = new(hi - lo) []byte {}
    for i := lo; i < hi; i++ {
        out[i - lo] = s[i]
    }
    ret out
}

// Cut slices s around the first occurrence of sep, returning the
// portion before sep, the portion after, and whether sep was present.
// If sep is not found in s, returns (copy-of-s, empty, false).
// Empty sep matches at position 0: returns (empty, copy-of-s, true).
// Mirrors Go 1.18's bytes.Cut surface.
fun Cut(s []byte, sep []byte) ([]byte, []byte, bool) {
    var n int = len(s)
    var nsep int = len(sep)
    if nsep == 0 {
        var before []byte = new(0) []byte {}
        var after []byte = new(n) []byte {}
        for i := 0; i < n; i++ { after[i] = s[i] }
        ret before, after, true
    }
    var idx int = Index(s, sep)
    if idx < 0 {
        var before []byte = new(n) []byte {}
        var after []byte = new(0) []byte {}
        for i := 0; i < n; i++ { before[i] = s[i] }
        ret before, after, false
    }
    var before []byte = new(idx) []byte {}
    for i := 0; i < idx; i++ { before[i] = s[i] }
    var off int = idx + nsep
    var alen int = n - off
    var after []byte = new(alen) []byte {}
    for i := 0; i < alen; i++ { after[i] = s[off + i] }
    ret before, after, true
}

// CutLast slices s around the LAST occurrence of sep — right-
// anchored mirror of Cut. Useful for path-vs-extension style
// splits where the rightmost separator matters. Empty sep returns
// (copy-of-s, empty, true).
fun CutLast(s []byte, sep []byte) ([]byte, []byte, bool) {
    var n int = len(s)
    var nsep int = len(sep)
    if nsep == 0 {
        var before []byte = new(n) []byte {}
        for i := 0; i < n; i++ { before[i] = s[i] }
        var after []byte = new(0) []byte {}
        ret before, after, true
    }
    var idx int = LastIndex(s, sep)
    if idx < 0 {
        var before []byte = new(n) []byte {}
        for i := 0; i < n; i++ { before[i] = s[i] }
        var after []byte = new(0) []byte {}
        ret before, after, false
    }
    var before []byte = new(idx) []byte {}
    for i := 0; i < idx; i++ { before[i] = s[i] }
    var off int = idx + nsep
    var alen int = n - off
    var after []byte = new(alen) []byte {}
    for i := 0; i < alen; i++ { after[i] = s[off + i] }
    ret before, after, true
}

// SplitN slices s into at most n subslices separated by sep, like
// Split but with a cap on the result length. n == 0 returns an empty
// slice; n < 0 returns the unbounded Split result. The last element
// holds the remainder including any further sep occurrences.
fun SplitN(s []byte, sep []byte, n int) [][]byte {
    if n == 0 {
        var empty [][]byte = new(0) [][]byte {}
        ret empty
    }
    if n < 0 { ret Split(s, sep) }
    if n == 1 {
        var single [][]byte = new(0) [][]byte {}
        var copy []byte = new(len(s)) []byte {}
        for i := 0; i < len(s); i++ { copy[i] = s[i] }
        single = append(single, copy)
        ret single
    }
    var ns int = len(s)
    var nsep int = len(sep)
    if nsep == 0 {
        var single [][]byte = new(0) [][]byte {}
        var copy []byte = new(ns) []byte {}
        for i := 0; i < ns; i++ { copy[i] = s[i] }
        single = append(single, copy)
        ret single
    }
    var out [][]byte = new(0) [][]byte {}
    var idx int = 0
    var start int = 0
    var i int = 0
    var limit int = ns - nsep
    for i <= limit {
        if idx == n - 1 { break }
        var match bool = true
        for j := 0; j < nsep; j++ {
            if s[i+j] != sep[j] { match = false; break }
        }
        if match {
            var piece []byte = new(i - start) []byte {}
            for k := start; k < i; k++ {
                piece[k - start] = s[k]
            }
            out = append(out, piece)
            idx = idx + 1
            i = i + nsep
            start = i
        } else {
            i = i + 1
        }
    }
    // Final piece: from `start` to end of s.
    var tail []byte = new(ns - start) []byte {}
    for k := start; k < ns; k++ {
        tail[k - start] = s[k]
    }
    out = append(out, tail)
    ret out
}

// Compare returns -1 if a < b, 0 if a == b, +1 if a > b (using
// byte-wise lexicographic ordering; ties broken by length). Useful
// as a comparator for `sort.IntsBy`-style helpers.
fun Compare(a []byte, b []byte) int {
    var na int = len(a)
    var nb int = len(b)
    var m int = na
    if nb < m { m = nb }
    for i := 0; i < m; i++ {
        var ai int = a[i] & 255
        var bi int = b[i] & 255
        if ai < bi { ret -1 }
        if ai > bi { ret 1 }
    }
    if na < nb { ret -1 }
    if na > nb { ret 1 }
    ret 0
}

// EqualFold reports whether a and b are equal under ASCII case-
// folding (case-insensitive compare). Non-ASCII bytes compare
// literally. Parallels strings.EqualFold.
fun EqualFold(a []byte, b []byte) bool {
    var n int = len(a)
    if len(b) != n { ret false }
    for i := 0; i < n; i++ {
        var ai int = a[i] & 255
        var bi int = b[i] & 255
        if ai >= 65 { if ai <= 90 { ai = ai + 32 } }
        if bi >= 65 { if bi <= 90 { bi = bi + 32 } }
        if ai != bi { ret false }
    }
    ret true
}

// IndexFunc returns the index of the first byte in s for which
// pred(b) is true, or -1 if no byte satisfies the predicate.
fun IndexFunc(s []byte, pred fun(byte) bool) int {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if pred(s[i]) { ret i }
    }
    ret -1
}

// LastIndexFunc returns the index of the last byte satisfying pred.
fun LastIndexFunc(s []byte, pred fun(byte) bool) int {
    for i := len(s) - 1; i >= 0; i = i - 1 {
        if pred(s[i]) { ret i }
    }
    ret -1
}

// TrimFunc returns s with leading + trailing bytes for which pred
// returns true removed. Allocates a fresh exact-size []byte.
fun TrimFunc(s []byte, pred fun(byte) bool) []byte {
    var n int = len(s)
    var lo int = 0
    for lo < n {
        if !pred(s[lo]) { break }
        lo = lo + 1
    }
    var hi int = n
    for hi > lo {
        if !pred(s[hi - 1]) { break }
        hi = hi - 1
    }
    var out []byte = new(hi - lo) []byte {}
    for i := lo; i < hi; i++ {
        out[i - lo] = s[i]
    }
    ret out
}

// String converts a []byte to an immutable string by copying the
// bytes. Convenience wrapper over the existing syscall.BytesToString
// intrinsic — useful when you have a []byte slice and want to feed
// it to a string-taking API (log.Println, strings.* functions, etc.).
fun String(b []byte) string {
    ret syscall.BytesToString(b, len(b))
}

// Reverse returns a new byte slice with the byte order of s
// reversed. Empty input returns an empty slice. Useful for
// bit-string reversal, palindrome generation, prefix-to-suffix
// conversions when working with byte arrays.
fun Reverse(s []byte) []byte {
    var n int = len(s)
    var out []byte = new(n) []byte {}
    for i := 0; i < n; i++ {
        out[i] = s[n - 1 - i]
    }
    ret out
}

// IsValidUtf8 reports whether the byte slice is a well-formed
// UTF-8 sequence. Empty returns true. Verifies leading-byte /
// trailing-byte structure but does NOT reject over-long encodings
// or surrogate-range code points. Counterpart to strings.IsValidUtf8.
fun IsValidUtf8(s []byte) bool {
    var n int = len(s)
    var i int = 0
    for i < n {
        var c int = s[i] & 255
        if c < 128 {
            i = i + 1
            continue
        }
        if c >= 248 { ret false }
        var need int = 0
        if c >= 240 { need = 3 }
        if c >= 224 {
            if c < 240 { need = 2 }
        }
        if c >= 192 {
            if c < 224 { need = 1 }
        }
        if need == 0 { ret false }
        if (i + need) >= n { ret false }
        var k int = 1
        for k <= need {
            var nc int = s[i + k] & 255
            if nc < 128 { ret false }
            if nc >= 192 { ret false }
            k = k + 1
        }
        i = i + 1 + need
    }
    ret true
}

// RuneCount returns the number of UTF-8 code points in the byte
// IsAscii reports whether every byte in s is in the 0..127 range.
// Empty slice returns true (vacuous truth). Counterpart to
// strings.IsAscii. Useful for fast-path branching: ASCII-only
// payloads can skip UTF-8 decode entirely.
fun IsAscii(s []byte) bool {
    var n int = len(s)
    for i := 0; i < n; i++ {
        if (s[i] & 255) >= 128 { ret false }
    }
    ret true
}

// Translate returns a fresh []byte with every byte that appears in
// `from` replaced by the byte at the corresponding position in `to`.
// If `from` is longer than `to`, the extra bytes are deleted (unix
// `tr -d` mode). Empty `from` returns a copy of s. Counterpart to
// strings.Translate.
fun Translate(s []byte, from []byte, to []byte) []byte {
    var nfrom int = len(from)
    var nto int = len(to)
    var ns int = len(s)
    var out []byte = new(0) []byte {}
    if nfrom == 0 {
        var copy []byte = new(ns) []byte {}
        for i := 0; i < ns; i++ { copy[i] = s[i] }
        ret copy
    }
    for i := 0; i < ns; i++ {
        var c byte = s[i]
        var idx int = -1
        for k := 0; k < nfrom; k++ {
            if from[k] == c { idx = k; break }
        }
        if idx < 0 {
            out = append(out, c)
            continue
        }
        if idx >= nto { continue }
        out = append(out, to[idx])
    }
    ret out
}

// RemoveChars returns a fresh []byte with every byte that appears
// in `chars` removed (including interior bytes — distinct from Trim
// which only strips ends). Empty chars returns a copy of s.
// Counterpart to strings.RemoveChars.
fun RemoveChars(s []byte, chars []byte) []byte {
    var nc int = len(chars)
    var n int = len(s)
    if nc == 0 {
        var copy []byte = new(n) []byte {}
        for i := 0; i < n; i++ { copy[i] = s[i] }
        ret copy
    }
    var out []byte = new(0) []byte {}
    for i := 0; i < n; i++ {
        if bytesCutsetContains(chars, s[i]) { continue }
        out = append(out, s[i])
    }
    ret out
}

// KeepOnly returns a fresh []byte containing only the bytes of s
// that appear in `chars` (whitelist filter — drop everything else).
// Byte-slice mirror of strings.KeepOnly. Empty chars returns an
// empty slice (nothing allowed). O(len(s) + len(chars)) via a
// 256-byte membership lookup. Useful for sanitizing payloads down
// to an allowed alphabet (digits-only, hex-only, etc.).
fun KeepOnly(s []byte, chars []byte) []byte {
    var cn int = len(chars)
    if cn == 0 { ret new(0) []byte {} }
    var n int = len(s)
    if n == 0 { ret new(0) []byte {} }
    var member []bool = new(256) []bool {}
    for i := 0; i < cn; i++ {
        var c int = chars[i] & 255
        member[c] = true
    }
    var out []byte = new(0) []byte {}
    for i := 0; i < n; i++ {
        var c int = s[i] & 255
        if member[c] { out = append(out, s[i]) }
    }
    ret out
}

// Levenshtein returns the minimum number of single-byte edits
// (insert / delete / substitute) to transform a into b. Two-row DP,
// O(na*nb) time / O(nb) space. Counterpart to strings.Levenshtein.
// Useful for binary fuzzy-match / approximate-equality of payloads
// (without an intermediate string conversion).
fun Levenshtein(a []byte, b []byte) int {
    var na int = len(a)
    var nb int = len(b)
    if na == 0 { ret nb }
    if nb == 0 { ret na }
    var prev []int = new(nb + 1) []int {}
    var curr []int = new(nb + 1) []int {}
    for j := 0; j <= nb; j++ { prev[j] = j }
    for i := 1; i <= na; i++ {
        curr[0] = i
        for j := 1; j <= nb; j++ {
            var cost int = 1
            if a[i - 1] == b[j - 1] { cost = 0 }
            var del int = prev[j] + 1
            var ins int = curr[j - 1] + 1
            var sub int = prev[j - 1] + cost
            var m int = del
            if ins < m { m = ins }
            if sub < m { m = sub }
            curr[j] = m
        }
        for j := 0; j <= nb; j++ { prev[j] = curr[j] }
    }
    ret prev[nb]
}

// OnlyHex returns a fresh []byte with every byte that isn't an
// ASCII hex digit (0-9, a-f, A-F) removed. Counterpart to
// strings.OnlyHex.
fun OnlyHex(s []byte) []byte {
    var n int = len(s)
    var out []byte = new(0) []byte {}
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 48 {
            if c <= 57 { out = append(out, c); continue }
        }
        if c >= 65 {
            if c <= 70 { out = append(out, c); continue }
        }
        if c >= 97 {
            if c <= 102 { out = append(out, c); continue }
        }
    }
    ret out
}

// OnlyDigits returns a fresh []byte with every non-ASCII-digit
// byte removed. Counterpart to strings.OnlyDigits.
fun OnlyDigits(s []byte) []byte {
    var n int = len(s)
    var out []byte = new(0) []byte {}
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 48 {
            if c <= 57 { out = append(out, c) }
        }
    }
    ret out
}

// OnlyAlphanumeric returns a fresh []byte with every non-ASCII
// letter or digit byte removed. Counterpart to strings.OnlyAlphanumeric.
fun OnlyAlphanumeric(s []byte) []byte {
    var n int = len(s)
    var out []byte = new(0) []byte {}
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c >= 48 {
            if c <= 57 { out = append(out, c); continue }
        }
        if c >= 65 {
            if c <= 90 { out = append(out, c); continue }
        }
        if c >= 97 {
            if c <= 122 { out = append(out, c); continue }
        }
    }
    ret out
}

// IndicesOfByte returns every position in s where the byte equals
// c. Counterpart to strings.IndicesOfByte — single-byte
// specialization of IndicesOf.
fun IndicesOfByte(s []byte, c byte) []int {
    var n int = len(s)
    var out []int = new(0) []int {}
    for i := 0; i < n; i++ {
        if s[i] == c { out = append(out, i) }
    }
    ret out
}

// IndexNthByte returns the index of the n-th occurrence (0-indexed)
// of byte c in s, or -1 if there are fewer than n+1 matches. n<0
// returns -1. Byte-slice mirror of strings.IndexNthByte.
fun IndexNthByte(s []byte, c byte, n int) int {
    if n < 0 { ret -1 }
    var ls int = len(s)
    var k int = 0
    for i := 0; i < ls; i++ {
        if s[i] == c {
            if k == n { ret i }
            k = k + 1
        }
    }
    ret -1
}

// IndexNth returns the starting position of the n-th non-overlapping
// occurrence (0-indexed) of sub in s, or -1 if there are fewer
// than n+1 matches. n<0 or empty sub returns -1. Byte-slice
// mirror of strings.IndexNth.
fun IndexNth(s []byte, sub []byte, n int) int {
    if n < 0 { ret -1 }
    var ls int = len(s)
    var lsub int = len(sub)
    if lsub == 0 { ret -1 }
    if ls < lsub { ret -1 }
    var i int = 0
    var limit int = ls - lsub
    var k int = 0
    for i <= limit {
        var match bool = true
        for j := 0; j < lsub; j++ {
            if s[i + j] != sub[j] {
                match = false
                break
            }
        }
        if match {
            if k == n { ret i }
            k = k + 1
            i = i + lsub
        } else {
            i = i + 1
        }
    }
    ret -1
}

// IndicesOf returns every starting position in s where sub
// appears. Non-overlapping matches. Empty sub or empty s returns
// empty. Counterpart to strings.IndicesOf.
fun IndicesOf(s []byte, sub []byte) []int {
    var out []int = new(0) []int {}
    var ls int = len(s)
    var lsub int = len(sub)
    if lsub == 0 { ret out }
    if ls < lsub { ret out }
    var i int = 0
    var limit int = ls - lsub
    for i <= limit {
        var match bool = true
        for j := 0; j < lsub; j++ {
            if s[i + j] != sub[j] {
                match = false
                break
            }
        }
        if match {
            out = append(out, i)
            i = i + lsub
        } else {
            i = i + 1
        }
    }
    ret out
}

// CommonPrefix returns a fresh []byte containing the longest byte
// sequence shared by a and b at the start. Counterpart to
// strings.CommonPrefix.
fun CommonPrefix(a []byte, b []byte) []byte {
    var na int = len(a)
    var nb int = len(b)
    var lim int = na
    if nb < lim { lim = nb }
    var k int = 0
    for k < lim {
        if a[k] != b[k] { break }
        k = k + 1
    }
    var out []byte = new(k) []byte {}
    for i := 0; i < k; i++ { out[i] = a[i] }
    ret out
}

// CommonSuffix returns the longest shared byte sequence at the end.
// Counterpart to strings.CommonSuffix.
fun CommonSuffix(a []byte, b []byte) []byte {
    var na int = len(a)
    var nb int = len(b)
    var lim int = na
    if nb < lim { lim = nb }
    var k int = 0
    for k < lim {
        if a[na - 1 - k] != b[nb - 1 - k] { break }
        k = k + 1
    }
    var out []byte = new(k) []byte {}
    for i := 0; i < k; i++ { out[i] = a[na - k + i] }
    ret out
}

// Truncate clamps s to ≤ maxBytes, appending `ellipsis` when
// truncation happens. Counterpart to strings.Truncate. maxBytes ≤ 0
// returns empty. If ellipsis is longer than maxBytes, returns the
// first maxBytes bytes of the ellipsis.
fun Truncate(s []byte, maxBytes int, ellipsis []byte) []byte {
    if maxBytes <= 0 { ret new(0) []byte {} }
    var n int = len(s)
    if n <= maxBytes {
        var copy []byte = new(n) []byte {}
        for i := 0; i < n; i++ { copy[i] = s[i] }
        ret copy
    }
    var eLen int = len(ellipsis)
    if eLen >= maxBytes {
        var out []byte = new(maxBytes) []byte {}
        for i := 0; i < maxBytes; i++ { out[i] = ellipsis[i] }
        ret out
    }
    var prefix int = maxBytes - eLen
    var out []byte = new(maxBytes) []byte {}
    for i := 0; i < prefix; i++ { out[i] = s[i] }
    for i := 0; i < eLen; i++ { out[prefix + i] = ellipsis[i] }
    ret out
}

// AbbreviateMiddle is the []byte counterpart of
// strings.AbbreviateMiddle. Keeps a balanced prefix + suffix with
// `ellipsis` in the middle. Useful for byte-payload preview where
// both ends are informative (file header + footer).
fun AbbreviateMiddle(s []byte, maxBytes int, ellipsis []byte) []byte {
    if maxBytes <= 0 { ret new(0) []byte {} }
    var n int = len(s)
    if n <= maxBytes {
        var copy []byte = new(n) []byte {}
        for i := 0; i < n; i++ { copy[i] = s[i] }
        ret copy
    }
    var eLen int = len(ellipsis)
    if eLen >= maxBytes {
        var head []byte = new(maxBytes) []byte {}
        for i := 0; i < maxBytes; i++ { head[i] = s[i] }
        ret head
    }
    var available int = maxBytes - eLen
    var leftLen int = available / 2 + (available % 2)
    var rightLen int = available - leftLen
    var out []byte = new(maxBytes) []byte {}
    for i := 0; i < leftLen; i++ { out[i] = s[i] }
    for i := 0; i < eLen; i++ { out[leftLen + i] = ellipsis[i] }
    for i := 0; i < rightLen; i++ { out[leftLen + eLen + i] = s[n - rightLen + i] }
    ret out
}

// AbbreviateLeft is the []byte counterpart of strings.AbbreviateLeft.
// Keeps the rightmost portion; prepends ellipsis.
fun AbbreviateLeft(s []byte, maxBytes int, ellipsis []byte) []byte {
    if maxBytes <= 0 { ret new(0) []byte {} }
    var n int = len(s)
    if n <= maxBytes {
        var copy []byte = new(n) []byte {}
        for i := 0; i < n; i++ { copy[i] = s[i] }
        ret copy
    }
    var eLen int = len(ellipsis)
    if eLen >= maxBytes {
        var out []byte = new(maxBytes) []byte {}
        for i := 0; i < maxBytes; i++ {
            out[i] = ellipsis[eLen - maxBytes + i]
        }
        ret out
    }
    var suffix int = maxBytes - eLen
    var out []byte = new(maxBytes) []byte {}
    for i := 0; i < eLen; i++ { out[i] = ellipsis[i] }
    for i := 0; i < suffix; i++ { out[eLen + i] = s[n - suffix + i] }
    ret out
}

// LongestLine returns the byte-length of the longest line in s
// (lines separated by `\n`). Empty input returns 0. Counterpart to
// strings.LongestLine.
fun LongestLine(s []byte) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = 0
    var current int = 0
    for i := 0; i < n; i++ {
        if s[i] == 10 {
            if current > best { best = current }
            current = 0
        } else {
            current = current + 1
        }
    }
    if current > best { best = current }
    ret best
}

// ShortestLine returns the byte-length of the shortest line in s.
// Empty lines count as 0. Counterpart to strings.ShortestLine.
fun ShortestLine(s []byte) int {
    var n int = len(s)
    if n == 0 { ret 0 }
    var best int = -1
    var current int = 0
    for i := 0; i < n; i++ {
        if s[i] == 10 {
            if best < 0 { best = current }
            if current < best { best = current }
            current = 0
        } else {
            current = current + 1
        }
    }
    if best < 0 { best = current }
    if current < best { best = current }
    ret best
}

// Frequencies returns a 256-bucket byte-frequency histogram of s.
// Counterpart to strings.Frequencies. Empty input returns 256
// zeros. Useful for entropy / charset / cryptanalysis tables in
// the binary path.
fun Frequencies(s []byte) []int {
    var hist []int = new(256) []int {}
    var n int = len(s)
    for i := 0; i < n; i++ {
        var idx int = s[i] & 255
        hist[idx] = hist[idx] + 1
    }
    ret hist
}

// MostCommonByte returns the byte value with the highest frequency
// in s. On ties, returns the smallest byte value with that count.
// Empty input returns 0. Counterpart to strings.MostCommonByte.
fun MostCommonByte(s []byte) byte {
    var hist []int = Frequencies(s)
    var bestByte int = 0
    var bestCount int = -1
    for i := 0; i < 256; i++ {
        if hist[i] > bestCount {
            bestCount = hist[i]
            bestByte = i
        }
    }
    var b byte = bestByte
    ret b
}

// HammingDistance returns the number of byte positions at which a
// and b differ. Both inputs must have the same length; returns -1
// on length mismatch. Counterpart to strings.HammingDistance.
// Useful for: binary-diff metrics, error-detection bit-flip counts,
// fixed-width fingerprint comparison.
fun HammingDistance(a []byte, b []byte) int {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret -1 }
    var d int = 0
    for i := 0; i < na; i++ {
        if a[i] != b[i] { d = d + 1 }
    }
    ret d
}

// IsAnagram reports whether a and b are byte-frequency permutations
// of each other via a 256-bucket histogram. Returns false on length
// mismatch. Counterpart to strings.IsAnagram. For binary payloads,
// this is the "do these two byte streams contain the same bytes
// (in any order)?" check.
fun IsAnagram(a []byte, b []byte) bool {
    var na int = len(a)
    var nb int = len(b)
    if na != nb { ret false }
    var hist []int = new(256) []int {}
    for i := 0; i < na; i++ {
        var ai int = a[i] & 255
        var bi int = b[i] & 255
        hist[ai] = hist[ai] + 1
        hist[bi] = hist[bi] - 1
    }
    for k := 0; k < 256; k++ {
        if hist[k] != 0 { ret false }
    }
    ret true
}

// slice. ASCII → 1 per byte; multi-byte sequences → 1 per leading
// byte. Continuation bytes are skipped via the step jump. Does
// NOT validate well-formedness. Counterpart to strings.RuneCount.
fun RuneCount(s []byte) int {
    var n int = len(s)
    var count int = 0
    var i int = 0
    for i < n {
        var c int = s[i] & 255
        var step int = 1
        if c >= 192 {
            step = 2
            if c >= 224 { step = 3 }
            if c >= 240 { step = 4 }
        }
        i = i + step
        count = count + 1
    }
    ret count
}

// NewReader wraps b as an io.Reader (one-shot: the first Read returns the
// whole content as a string, then "" = EOF). It returns the io.Reader
// interface rather than a concrete `bytes.Reader` because volt's type
// namespace is global and `Reader` is io's interface — the concrete impl
// is io.StringReader. The []byte is read (copied to a string) at call time.
fun NewReader(b []byte) io.Reader {
    ret io.NewStringReader(syscall.BytesToString(b, len(b)))
}
