// Package hex: hexadecimal encoding + decoding of byte sequences.
//
// Surface:
//   EncodeToString(src string) string         — bytes → 2-char lowercase hex per byte
//   DecodeString(src string) (string, error)  — hex → bytes; error on odd length or bad nibble
//
// Volt strings are immutable byte sequences, so they serve as both
// the input and output for binary payloads. Output is always
// lowercase a–f.

package hex

import "errors"
import "bytes"

// hexChar maps a 4-bit nibble (0..15) to its lowercase ASCII char.
fun hexChar(n int) byte {
    if n < 10 { ret 48 + n }      // '0'..'9'
    ret 87 + n                    // 'a'..'f' = 97 + (n - 10) = 87 + n
}

// nibble parses a hex char to its 4-bit value, or -1 if not a hex digit.
// Accepts '0'..'9', 'a'..'f', 'A'..'F'.
fun nibble(c byte) int {
    if c >= 48 {
        if c <= 57 { ret c - 48 }       // '0'..'9'
    }
    if c >= 97 {
        if c <= 102 { ret c - 87 }      // 'a'..'f'
    }
    if c >= 65 {
        if c <= 70 { ret c - 55 }       // 'A'..'F'
    }
    ret -1
}

// EncodeToString returns the hex encoding of src — two lowercase
// chars per input byte. Length of the result is 2*len(src).
// O(n) via bytes.Builder (Pass 108) — was O(n²) naive concat.
fun EncodeToString(src string) string {
    var n int = len(src)
    var b *bytes.Builder = bytes.NewBuilder()
    for i:=0; i < n; i++ {
        var by int = src[i] & 255
        b.WriteByte(hexChar(by >> 4))
        b.WriteByte(hexChar(by & 15))
    }
    ret b.String()
}

// hexCharUpper maps a 4-bit nibble (0..15) to its uppercase ASCII char.
fun hexCharUpper(n int) byte {
    if n < 10 { ret 48 + n }      // '0'..'9'
    ret 55 + n                    // 'A'..'F' = 65 + (n - 10) = 55 + n
}

// EncodeToStringUpper is the uppercase variant of EncodeToString —
// two uppercase hex chars per input byte. Useful for protocols /
// display conventions that expect uppercase (Windows-style hash
// dumps, some hardware-token formats, RFC 4648 §8 base16). Length
// of the result is 2*len(src). Output round-trips with DecodeString,
// which accepts both cases.
fun EncodeToStringUpper(src string) string {
    var n int = len(src)
    var b *bytes.Builder = bytes.NewBuilder()
    for i:=0; i < n; i++ {
        var by int = src[i] & 255
        b.WriteByte(hexCharUpper(by >> 4))
        b.WriteByte(hexCharUpper(by & 15))
    }
    ret b.String()
}

// EncodedLen returns the length in bytes of the hex encoding of n
// input bytes. Trivially `2 * n` — useful for pre-allocating a
// buffer that will hold the encoding without first calling
// EncodeToString.
fun EncodedLen(n int) int {
    ret 2 * n
}

// DecodedLen returns the length in bytes of the decoding of n hex
// characters. Trivially `n / 2` — input is expected to have an even
// length; odd inputs are decode errors, but DecodedLen returns the
// truncated count rather than -1 (matching Go's stdlib semantics).
fun DecodedLen(n int) int {
    ret n / 2
}

// DecodeString decodes the hex representation in src. Returns the
// decoded bytes (as a string) and an error if src has odd length or
// any non-hex character.
fun DecodeString(src string) (string, error) {
    var n int = len(src)
    if (n % 2) != 0 {
        ret "", errors.New("hex: odd length input")
    }
    var b *bytes.Builder = bytes.NewBuilder()
    var i int = 0
    for i < n {
        var hi int = nibble(src[i])
        var lo int = nibble(src[i+1])
        if hi < 0 {
            ret "", errors.New("hex: bad nibble")
        }
        if lo < 0 {
            ret "", errors.New("hex: bad nibble")
        }
        var by byte = (hi << 4) | lo
        b.WriteByte(by)
        i = i + 2
    }
    ret b.String(), nil
}
