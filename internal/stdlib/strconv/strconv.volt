// Package strconv: integer ↔ string conversion.
//
// Decimal:
//   Atoi(s)     — parse decimal int (leading '-' allowed)
//   Itoa(n)     — format int in base 10
//
// Arbitrary base (2..36):
//   ParseInt(s, base)   — letters case-insensitive
//   FormatInt(n, base)  — lowercase digits for 10..35
//
// Float ParseFloat / FormatFloat are deferred — they need explicit
// int(f) / float(i) casts (or runtime helpers) that don't exist yet.
//
// All pure volt source — no codegen intrinsics needed beyond what
// already exists for strings.

package strconv

import "errors"
import "bytes"

// Atoi parses s as a signed decimal integer.
// Returns (0, error) on empty input or any non-digit character.
fun Atoi(s string) (int, error) {
    var n int = len(s)
    if n == 0 {
        ret 0, errors.New("Atoi: empty string")
    }
    var i int = 0
    var neg bool = false
    if s[0] == 45 {           // '-'
        neg = true
        i = 1
    }
    if i == n {
        ret 0, errors.New("Atoi: lone sign")
    }
    var v int = 0
    for i < n {
        var c byte = s[i]
        if c < 48 {
            ret 0, errors.New("Atoi: non-digit")
        }
        if c > 57 {
            ret 0, errors.New("Atoi: non-digit")
        }
        var d int = c - 48
        v = v * 10 + d
        i = i + 1
    }
    if neg {
        v = 0 - v
    }
    ret v, nil
}

// Itoa returns the decimal representation of n.
// O(n_digits) via bytes.Builder + WriteInt — handles MinInt correctly
// (the absolute-value-of-MinInt overflow trick lives in WriteInt).
fun Itoa(n int) string {
    var b bytes.Builder = new bytes.Builder{}
    b.WriteInt(n)
    ret b.String()
}

// digitValue returns the integer value of an ASCII digit/letter in
// base 2..36, or -1 if c is not a valid digit. Accepts '0'..'9',
// 'a'..'z', 'A'..'Z'.
fun digitValue(c byte) int {
    if c >= 48 {                    // '0'
        if c <= 57 { ret c - 48 }
    }
    if c >= 97 {                    // 'a'
        if c <= 122 { ret c - 87 } // 'a'..'z' → 10..35
    }
    if c >= 65 {                    // 'A'
        if c <= 90 { ret c - 55 }  // 'A'..'Z' → 10..35
    }
    ret -1
}

// digitChar returns the lowercase ASCII char for an integer digit
// d in [0, 35]. Caller is responsible for keeping d in range.
fun digitChar(d int) byte {
    if d < 10 { ret 48 + d }       // '0' + d
    ret 87 + d                     // 'a' + (d - 10)
}

// ParseInt parses s as an integer in the given base. base must be in
// [2, 36]. A leading '-' indicates a negative number. Returns
// (0, error) on any malformed input.
fun ParseInt(s string, base int) (int, error) {
    if base < 2 { ret 0, errors.New("ParseInt: base out of range") }
    if base > 36 { ret 0, errors.New("ParseInt: base out of range") }
    var n int = len(s)
    if n == 0 { ret 0, errors.New("ParseInt: empty string") }
    var i int = 0
    var neg bool = false
    if s[0] == 45 {                 // '-'
        neg = true
        i = 1
    }
    if i == n { ret 0, errors.New("ParseInt: lone sign") }
    var v int = 0
    for i < n {
        var d int = digitValue(s[i])
        if d < 0 { ret 0, errors.New("ParseInt: bad digit") }
        if d >= base { ret 0, errors.New("ParseInt: bad digit") }
        v = v * base + d
        i = i + 1
    }
    if neg { v = 0 - v }
    ret v, nil
}

// ParseBool returns the boolean value represented by s. Accepts the
// Go-compatible forms: "1"/"t"/"T"/"TRUE"/"true"/"True" → true;
// "0"/"f"/"F"/"FALSE"/"false"/"False" → false. Anything else is an
// error and the returned bool is false.
fun ParseBool(s string) (bool, error) {
    if s == "1"     { ret true, nil }
    if s == "t"     { ret true, nil }
    if s == "T"     { ret true, nil }
    if s == "true"  { ret true, nil }
    if s == "TRUE"  { ret true, nil }
    if s == "True"  { ret true, nil }
    if s == "0"     { ret false, nil }
    if s == "f"     { ret false, nil }
    if s == "F"     { ret false, nil }
    if s == "false" { ret false, nil }
    if s == "FALSE" { ret false, nil }
    if s == "False" { ret false, nil }
    ret false, errors.New("strconv: invalid bool literal")
}

// FormatBool returns "true" or "false" for b. Mirrors Go's surface.
fun FormatBool(b bool) string {
    if b { ret "true" }
    ret "false"
}

// FormatInt returns the representation of n in the given base. base
// must be in [2, 36]; out-of-range bases return "" (no error path
// in v1 — caller validates).
fun FormatInt(n int, base int) string {
    if base < 2 { ret "" }
    if base > 36 { ret "" }
    if n == 0 { ret "0" }
    // Buffer digits LSB-first into a small scratch slice, then emit
    // MSB-first via a bytes.Builder. Operates on the negative form to
    // dodge -MinInt overflow (same trick bytes.Builder.WriteInt uses).
    var b bytes.Builder = new bytes.Builder{}
    var neg bool = false
    if n < 0 {
        neg = true
        // Buffer digits while n is still negative.
        var tmp []byte = new(64) []byte {}
        var nd int = 0
        for n != 0 {
            var d int = -(n % base)
            tmp[nd] = digitChar(d)
            nd = nd + 1
            n = n / base
        }
        b.WriteByte(45)   // '-'
        for i := nd - 1; i >= 0; i = i - 1 {
            b.WriteByte(tmp[i])
        }
        if !neg { neg = true }   // keep neg live
        ret b.String()
    }
    var tmp []byte = new(64) []byte {}
    var nd int = 0
    for n != 0 {
        var d int = n % base
        tmp[nd] = digitChar(d)
        nd = nd + 1
        n = n / base
    }
    for i := nd - 1; i >= 0; i = i - 1 {
        b.WriteByte(tmp[i])
    }
    ret b.String()
}

// Quote returns a Go-syntax double-quoted string for s with the
// standard escape sequences for control / quote / backslash bytes
// plus `\xNN` for any other non-printable byte (< 0x20 or == 0x7F).
// Roughly mirrors Go's strconv.Quote — adequate for log/debug output
// and for emitting volt-source-compatible literals.
fun Quote(s string) string {
    var b bytes.Builder = new bytes.Builder{}
    b.WriteByte(34)  // '"'
    var n int = len(s)
    for i := 0; i < n; i++ {
        var c byte = s[i]
        if c == 34 { b.WriteString("\\\"") } else
        if c == 92 { b.WriteString("\\\\") } else
        if c == 7  { b.WriteString("\\a")  } else
        if c == 8  { b.WriteString("\\b")  } else
        if c == 9  { b.WriteString("\\t")  } else
        if c == 10 { b.WriteString("\\n")  } else
        if c == 11 { b.WriteString("\\v")  } else
        if c == 12 { b.WriteString("\\f")  } else
        if c == 13 { b.WriteString("\\r")  } else {
            // Printable ASCII (0x20 .. 0x7E) emits as-is; everything
            // else uses the \xNN hex-escape.
            // byte values widen with sign-extension; the s[i] & 255
            // mask trick (used by encoding/hex.EncodeToString) forces
            // the operand into int width without preserving the sign.
            var bi int = s[i] & 255
            if bi >= 32 {
                if bi <= 126 {
                    b.WriteByte(c)
                } else {
                    b.WriteString("\\x")
                    b.WriteByte(hexNibble(bi / 16))
                    b.WriteByte(hexNibble(bi % 16))
                }
            } else {
                b.WriteString("\\x")
                b.WriteByte(hexNibble(bi / 16))
                b.WriteByte(hexNibble(bi % 16))
            }
        }
    }
    b.WriteByte(34)
    ret b.String()
}

// hexNibble maps a 0..15 nibble value to its lowercase hex byte.
fun hexNibble(n int) byte {
    if n < 10 { ret 48 + n }   // '0' + n
    ret 87 + n                 // 'a' + (n-10)
}

// Unquote interprets s as a Go-syntax double-quoted string and
// returns the unescaped content. Errors when s lacks the wrapping
// quotes, contains an unterminated/unknown escape, or contains an
// embedded literal `"`. Mirrors the Quote ↔ Unquote round-trip:
// Unquote(Quote(s)) == s for all volt byte strings.
fun Unquote(s string) (string, error) {
    var n int = len(s)
    if n < 2 { ret "", errors.New("strconv: too short") }
    if s[0] != 34 { ret "", errors.New("strconv: missing opening quote") }
    if s[n-1] != 34 { ret "", errors.New("strconv: missing closing quote") }
    var b bytes.Builder = new bytes.Builder{}
    var i int = 1
    var limit int = n - 1
    for i < limit {
        var c byte = s[i]
        if c == 34 {
            ret "", errors.New("strconv: unescaped quote in body")
        }
        if c == 92 {                       // '\\'
            if i + 1 >= limit {
                ret "", errors.New("strconv: dangling escape")
            }
            var esc byte = s[i+1]
            if esc == 34       { b.WriteByte(34); i = i + 2 } else
            if esc == 92       { b.WriteByte(92); i = i + 2 } else
            if esc == 97       { b.WriteByte(7);  i = i + 2 } else  // \a
            if esc == 98       { b.WriteByte(8);  i = i + 2 } else  // \b
            if esc == 116      { b.WriteByte(9);  i = i + 2 } else  // \t
            if esc == 110      { b.WriteByte(10); i = i + 2 } else  // \n
            if esc == 118      { b.WriteByte(11); i = i + 2 } else  // \v
            if esc == 102      { b.WriteByte(12); i = i + 2 } else  // \f
            if esc == 114      { b.WriteByte(13); i = i + 2 } else  // \r
            if esc == 120 {                                          // \xNN
                if i + 3 >= limit {
                    ret "", errors.New("strconv: short \\x escape")
                }
                var hi int = nibbleValue(s[i+2])
                var lo int = nibbleValue(s[i+3])
                if hi < 0 {
                    ret "", errors.New("strconv: bad hex digit after \\x")
                }
                if lo < 0 {
                    ret "", errors.New("strconv: bad hex digit after \\x")
                }
                var by byte = (hi << 4) | lo
                b.WriteByte(by)
                i = i + 4
            } else {
                ret "", errors.New("strconv: unknown escape")
            }
        } else {
            b.WriteByte(c)
            i = i + 1
        }
    }
    ret b.String(), nil
}

// nibbleValue maps an ASCII hex digit ('0'..'9' / 'a'..'f' / 'A'..'F')
// to its 0..15 value, or -1 if c isn't a valid hex byte.
fun nibbleValue(c byte) int {
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

// AppendInt appends the base-`base` representation of n to dst and
// returns the extended slice. Mirrors Go's strconv.AppendInt — useful
// for performance-conscious code that wants to avoid string-conversion
// allocations when accumulating into an existing []byte buffer.
fun AppendInt(dst []byte, n int, base int) []byte {
    var s string = FormatInt(n, base)
    var ns int = len(s)
    var nd int = len(dst)
    var out []byte = new(nd + ns) []byte {}
    for i := 0; i < nd; i++ { out[i] = dst[i] }
    for i := 0; i < ns; i++ { out[nd + i] = s[i] }
    ret out
}

// AppendBool appends "true" or "false" to dst.
fun AppendBool(dst []byte, b bool) []byte {
    var s string = FormatBool(b)
    var ns int = len(s)
    var nd int = len(dst)
    var out []byte = new(nd + ns) []byte {}
    for i := 0; i < nd; i++ { out[i] = dst[i] }
    for i := 0; i < ns; i++ { out[nd + i] = s[i] }
    ret out
}

// AtoiOr parses s as a decimal integer; if parsing fails, returns
// `defaultValue` instead of an error. Ergonomic for config / env-var
// reads where "missing or malformed → use the default" is the
// natural semantic (e.g. `port := strconv.AtoiOr(os.Getenv("PORT"), 8080)`).
fun AtoiOr(s string, defaultValue int) int {
    var v int = 0
    var err error = nil
    v, err = Atoi(s)
    if err != nil { ret defaultValue }
    ret v
}

// ParseBoolOr parses s as a bool literal; if parsing fails, returns
// `defaultValue`. Same ergonomic intent as AtoiOr — flag/env parse
// with a fallback. Accepted true forms: "1" / "t" / "T" / "true" /
// "TRUE" / "True"; false forms: "0" / "f" / "F" / "false" / "FALSE"
// / "False". Anything else returns `defaultValue`.
fun ParseBoolOr(s string, defaultValue bool) bool {
    var v bool = false
    var err error = nil
    v, err = ParseBool(s)
    if err != nil { ret defaultValue }
    ret v
}

// ParseIntOr parses s in the given base (2..36); if parsing fails,
// returns `defaultValue`. The base-aware sibling of AtoiOr —
// useful for parsing hex (`base=16`), octal (`base=8`), or binary
// (`base=2`) config values where a missing or malformed value
// should fall back to a sane default. Completes the "Or" parse
// trio with AtoiOr and ParseBoolOr.
fun ParseIntOr(s string, base int, defaultValue int) int {
    var v int = 0
    var err error = nil
    v, err = ParseInt(s, base)
    if err != nil { ret defaultValue }
    ret v
}

// FormatHex returns n in lowercase hexadecimal (no `0x` prefix).
// Equivalent to `FormatInt(n, 16)` — kept as a separate name for
// intent-revealing call sites: `addr := strconv.FormatHex(ip)` reads
// more directly than `FormatInt(ip, 16)`.
fun FormatHex(n int) string {
    ret FormatInt(n, 16)
}

// FormatBinary returns n in base-2 (no `0b` prefix). Useful for
// debug dumps of flags / bitfields.
fun FormatBinary(n int) string {
    ret FormatInt(n, 2)
}

// FormatOctal returns n in base-8 (no `0o` prefix). Useful for
// rendering POSIX file modes (`0755 == 493 decimal`,
// `FormatOctal(493) == "755"`).
fun FormatOctal(n int) string {
    ret FormatInt(n, 8)
}

// FormatHexPad returns n in lowercase base-16, left-padded with '0'
// to at least width characters. Negative n keeps the leading '-'
// sign and pads the digits after it (so the visible field width
// for negatives is width+1). Width <= len(digits) returns the
// digits unpadded. Useful for hex dumps, fixed-width addresses
// (e.g. `FormatHexPad(255, 4) == "00ff"`), and MAC-octet rendering.
fun FormatHexPad(n int, width int) string {
    var s string = FormatHex(n)
    var neg bool = false
    if len(s) > 0 {
        if s[0] == 45 {   // '-'
            neg = true
            s = "" + s
        }
    }
    if neg {
        var body string = ""
        for i := 1; i < len(s); i++ {
            body = body + chr(s[i])
        }
        var need int = width - len(body)
        if need <= 0 { ret s }
        var pad string = ""
        for i := 0; i < need; i++ { pad = pad + "0" }
        ret "-" + pad + body
    }
    var need int = width - len(s)
    if need <= 0 { ret s }
    var pad string = ""
    for i := 0; i < need; i++ { pad = pad + "0" }
    ret pad + s
}

// FormatBinaryPad returns n in base-2 left-padded with '0' to at
// least width characters. Same sign handling as FormatHexPad.
// Useful for fixed-width bitmask / flag-field debug rendering
// (`FormatBinaryPad(5, 8) == "00000101"`).
fun FormatBinaryPad(n int, width int) string {
    var s string = FormatBinary(n)
    var neg bool = false
    if len(s) > 0 {
        if s[0] == 45 {
            neg = true
            s = "" + s
        }
    }
    if neg {
        var body string = ""
        for i := 1; i < len(s); i++ {
            body = body + chr(s[i])
        }
        var need int = width - len(body)
        if need <= 0 { ret s }
        var pad string = ""
        for i := 0; i < need; i++ { pad = pad + "0" }
        ret "-" + pad + body
    }
    var need int = width - len(s)
    if need <= 0 { ret s }
    var pad string = ""
    for i := 0; i < need; i++ { pad = pad + "0" }
    ret pad + s
}
