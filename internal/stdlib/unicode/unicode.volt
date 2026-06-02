// Package unicode: byte-level (ASCII) classification + case folding.
//
// Volt strings are immutable byte sequences and the language doesn't
// have a rune type, so this package is an ASCII-focused subset of
// Go's `unicode` package: each predicate / mapper takes a single
// `byte` and returns a `bool` / `byte`. Non-ASCII bytes get false /
// pass-through behavior — adequate for the parser, JSON, and
// strconv use cases that need character classification.

package unicode

// IsDigit reports whether b is an ASCII decimal digit '0'..'9'.
fun IsDigit(b byte) bool {
    if b >= 48 {
        if b <= 57 { ret true }
    }
    ret false
}

// IsLower reports whether b is an ASCII lowercase letter 'a'..'z'.
fun IsLower(b byte) bool {
    if b >= 97 {
        if b <= 122 { ret true }
    }
    ret false
}

// IsUpper reports whether b is an ASCII uppercase letter 'A'..'Z'.
fun IsUpper(b byte) bool {
    if b >= 65 {
        if b <= 90 { ret true }
    }
    ret false
}

// IsLetter reports whether b is an ASCII letter (either case).
fun IsLetter(b byte) bool {
    if IsUpper(b) { ret true }
    ret IsLower(b)
}

// IsSpace reports whether b is one of the standard ASCII whitespace
// bytes — space, tab, CR, LF, vertical tab, form feed.
fun IsSpace(b byte) bool {
    if b == 32 { ret true }              // ' '
    if b == 9  { ret true }              // '\t'
    if b == 10 { ret true }              // '\n'
    if b == 13 { ret true }              // '\r'
    if b == 11 { ret true }              // '\v'
    if b == 12 { ret true }              // '\f'
    ret false
}

// IsAlpha is a synonym for IsLetter.
fun IsAlpha(b byte) bool { ret IsLetter(b) }

// IsAlphanumeric reports whether b is a letter or digit.
fun IsAlphanumeric(b byte) bool {
    if IsLetter(b) { ret true }
    ret IsDigit(b)
}

// IsPrint reports whether b is a printable ASCII character: space
// through `~` (0x20..0x7E). Newline / tab are NOT printable per Go.
fun IsPrint(b byte) bool {
    if b >= 32 {
        if b <= 126 { ret true }
    }
    ret false
}

// ToUpper folds an ASCII lowercase letter to uppercase. Other bytes
// pass through unchanged.
fun ToUpper(b byte) byte {
    if IsLower(b) { ret b - 32 }
    ret b
}

// ToLower folds an ASCII uppercase letter to lowercase.
fun ToLower(b byte) byte {
    if IsUpper(b) { ret b + 32 }
    ret b
}

// SwapCase flips the case of an ASCII letter: 'A' ↔ 'a'. Non-letter
// bytes pass through unchanged. The per-byte primitive behind
// `strings.SwapCase` — useful in custom case-folding loops where
// you need branch-free swap at each position.
fun SwapCase(b byte) byte {
    if IsUpper(b) { ret b + 32 }
    if IsLower(b) { ret b - 32 }
    ret b
}

// IsHex reports whether b is a hexadecimal ASCII digit:
// '0'..'9', 'a'..'f', or 'A'..'F'.
fun IsHex(b byte) bool {
    if b >= 48 { if b <= 57 { ret true } }   // '0'..'9'
    if b >= 97 { if b <= 102 { ret true } }  // 'a'..'f'
    if b >= 65 { if b <= 70 { ret true } }   // 'A'..'F'
    ret false
}

// IsControl reports whether b is an ASCII control character —
// 0x00..0x1F or 0x7F (DEL). Anything outside those bounds (i.e.
// 0x20..0x7E or 0x80..0xFF) is not a control character.
fun IsControl(b byte) bool {
    if b < 32 { ret true }
    if b == 127 { ret true }
    ret false
}

// IsPunct reports whether b is an ASCII punctuation byte:
// any printable ASCII that isn't a letter, digit, or space.
// Covers: !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
fun IsPunct(b byte) bool {
    if b < 33 { ret false }
    if b > 126 { ret false }
    if IsLetter(b) { ret false }
    if IsDigit(b) { ret false }
    ret true
}

// DigitValue returns the integer value (0..9) of an ASCII decimal
// digit, or -1 if b is not a digit. The natural companion to
// IsDigit — covers the parser pattern `if IsDigit(c) { v = v*10 + c - '0' }`
// in one branch-free call.
fun DigitValue(b byte) int {
    if b >= 48 {
        if b <= 57 { ret b - 48 }
    }
    ret -1
}

// HexDigitValue returns the integer value (0..15) of an ASCII hex
// digit (`0`..`9`, `a`..`f`, `A`..`F`), or -1 if b is not a hex
// digit. Useful in `\uHHHH`, percent-decoding, hex-string parsing,
// and color-literal parsing.
fun HexDigitValue(b byte) int {
    if b >= 48 { if b <= 57  { ret b - 48 } }       // '0'..'9'
    if b >= 97 { if b <= 102 { ret b - 97 + 10 } }  // 'a'..'f'
    if b >= 65 { if b <= 70  { ret b - 65 + 10 } }  // 'A'..'F'
    ret -1
}
