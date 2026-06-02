// Package base64: standard base64 encoding (RFC 4648 §4).
//
// Surface:
//   EncodeToString(src string) string        — bytes → ASCII base64
//   DecodeString(src string) (string, error) — base64 → bytes; error on
//                                              bad char or wrong padding
//
// Uses the standard alphabet `A-Za-z0-9+/` with `=` padding. Pure volt
// over the bitwise/shift operators landed in pass 65.

package base64

import "errors"
import "bytes"

// alphaChar maps a 6-bit value (0..63) to its base64 ASCII char.
fun alphaChar(n int) byte {
    if n < 26 { ret 65 + n }            // 'A'..'Z'
    if n < 52 { ret 97 + (n - 26) }     // 'a'..'z'
    if n < 62 { ret 48 + (n - 52) }     // '0'..'9'
    if n == 62 { ret 43 }               // '+'
    ret 47                              // '/'
}

// alphaVal decodes a base64 ASCII char to its 6-bit value, or -1 if
// not a valid base64 char (callers treat '=' separately).
fun alphaVal(c byte) int {
    if c >= 65 {
        if c <= 90 { ret c - 65 }        // 'A'..'Z'
    }
    if c >= 97 {
        if c <= 122 { ret c - 97 + 26 }  // 'a'..'z'
    }
    if c >= 48 {
        if c <= 57 { ret c - 48 + 52 }   // '0'..'9'
    }
    if c == 43 { ret 62 }                // '+'
    if c == 47 { ret 63 }                // '/'
    ret -1
}

// EncodeToString returns the standard base64 encoding of src with
// `=` padding. Output length is always a multiple of 4. O(n) via
// bytes.Builder (Pass 108) — was O(n²) naive concat.
fun EncodeToString(src string) string {
    var b *bytes.Builder = bytes.NewBuilder()
    var n int = len(src)
    var i int = 0
    for i+3 <= n {
        var b0 int = src[i]   & 255
        var b1 int = src[i+1] & 255
        var b2 int = src[i+2] & 255
        b.WriteByte(alphaChar(b0 >> 2))
        b.WriteByte(alphaChar(((b0 & 3) << 4) | (b1 >> 4)))
        b.WriteByte(alphaChar(((b1 & 15) << 2) | (b2 >> 6)))
        b.WriteByte(alphaChar(b2 & 63))
        i = i + 3
    }
    var rem int = n - i
    if rem == 1 {
        var b0 int = src[i] & 255
        b.WriteByte(alphaChar(b0 >> 2))
        b.WriteByte(alphaChar((b0 & 3) << 4))
        b.WriteByte(61)   // '='
        b.WriteByte(61)
    }
    if rem == 2 {
        var b0 int = src[i]   & 255
        var b1 int = src[i+1] & 255
        b.WriteByte(alphaChar(b0 >> 2))
        b.WriteByte(alphaChar(((b0 & 3) << 4) | (b1 >> 4)))
        b.WriteByte(alphaChar((b1 & 15) << 2))
        b.WriteByte(61)
    }
    ret b.String()
}

// EncodeToStringURL returns the URL-safe (RFC 4648 §5) base64
// encoding of src — the standard encoding with `+` → `-` and `/` →
// `_`. Output retains `=` padding (matches Go's URLEncoding; callers
// who want padding-stripped output can trim the trailing `=`s). Use
// for JWTs, URL query parameters, cookie values, filename-safe
// identifiers.
fun EncodeToStringURL(src string) string {
    var s string = EncodeToString(src)
    var n int = len(s)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 43 { b.WriteByte(45); continue }    // '+' → '-'
        if c == 47 { b.WriteByte(95); continue }    // '/' → '_'
        b.WriteByte(c)
    }
    ret b.String()
}

// DecodeStringURL decodes a URL-safe base64 string. Maps `-` → `+`
// and `_` → `/`, then forwards to DecodeString. Missing `=` padding
// is re-added so input length 4n+2 / 4n+3 (raw-URL-encoded forms) is
// accepted in addition to fully-padded 4n input. Length-1 mod 4
// inputs propagate the standard decode error.
fun DecodeStringURL(src string) (string, error) {
    var n int = len(src)
    var b *bytes.Builder = bytes.NewBuilder()
    for i := 0; i < n; i++ {
        var c byte = src[i]
        if c == 45 { b.WriteByte(43); continue }    // '-' → '+'
        if c == 95 { b.WriteByte(47); continue }    // '_' → '/'
        b.WriteByte(c)
    }
    var rem int = b.Len() % 4
    if rem == 2 {
        b.WriteByte(61)
        b.WriteByte(61)
    } else {
        if rem == 3 {
            b.WriteByte(61)
        }
    }
    var out string = ""
    var err error = nil
    out, err = DecodeString(b.String())
    ret out, err
}

// DecodeString decodes a standard-base64 string. Returns the decoded
// bytes (as a string) and an error if the input has invalid length,
// stray padding, or non-base64 characters.
fun DecodeString(src string) (string, error) {
    var n int = len(src)
    if (n % 4) != 0 {
        ret "", errors.New("base64: input length not a multiple of 4")
    }
    if n == 0 { ret "", nil }
    // Count trailing `=` (0, 1, or 2).
    var pad int = 0
    if src[n-1] == 61 { pad = 1 }       // '='
    if pad == 1 {
        if src[n-2] == 61 { pad = 2 }
    }
    if pad > 2 {
        ret "", errors.New("base64: too much padding")
    }
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    var limit int = n - 4
    for i <= limit {
        var c0 byte = src[i]
        var c1 byte = src[i+1]
        var c2 byte = src[i+2]
        var c3 byte = src[i+3]
        var v0 int = alphaVal(c0)
        var v1 int = alphaVal(c1)
        var v2 int = alphaVal(c2)
        var v3 int = alphaVal(c3)
        if v0 < 0 { ret "", errors.New("base64: bad char") }
        if v1 < 0 { ret "", errors.New("base64: bad char") }
        // Last group: `=` padding allowed in v2 and v3.
        if i == limit {
            if v2 < 0 {
                if c2 != 61 { ret "", errors.New("base64: bad char") }
            }
            if v3 < 0 {
                if c3 != 61 { ret "", errors.New("base64: bad char") }
            }
            var bb0 byte = (v0 << 2) | (v1 >> 4)
            b.WriteByte(bb0)
            if c2 != 61 {
                var bb1 byte = ((v1 & 15) << 4) | (v2 >> 2)
                b.WriteByte(bb1)
                if c3 != 61 {
                    var bb2 byte = ((v2 & 3) << 6) | v3
                    b.WriteByte(bb2)
                }
            } else {
                if c3 != 61 {
                    ret "", errors.New("base64: stray padding")
                }
            }
            ret b.String(), nil
        }
        if v2 < 0 { ret "", errors.New("base64: bad char") }
        if v3 < 0 { ret "", errors.New("base64: bad char") }
        var bb0 byte = (v0 << 2) | (v1 >> 4)
        b.WriteByte(bb0)
        var bb1 byte = ((v1 & 15) << 4) | (v2 >> 2)
        b.WriteByte(bb1)
        var bb2 byte = ((v2 & 3) << 6) | v3
        b.WriteByte(bb2)
        i = i + 4
    }
    ret b.String(), nil
}
