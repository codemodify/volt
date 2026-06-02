package main
import "log"
import "unicode"

// Positive test: unicode.IsHex / IsControl / IsPunct.

fun main() int {
	var pass int = 0

	// IsHex.
	if unicode.IsHex(48) { pass = pass + 1 }    // '0'
	if unicode.IsHex(57) { pass = pass + 1 }    // '9'
	if unicode.IsHex(97) { pass = pass + 1 }    // 'a'
	if unicode.IsHex(102) { pass = pass + 1 }   // 'f'
	if unicode.IsHex(65) { pass = pass + 1 }    // 'A'
	if unicode.IsHex(70) { pass = pass + 1 }    // 'F'
	if !unicode.IsHex(103) { pass = pass + 1 }  // 'g' — not hex
	if !unicode.IsHex(71) { pass = pass + 1 }   // 'G' — not hex
	if !unicode.IsHex(58) { pass = pass + 1 }   // ':' — between '9' and 'A'
	if !unicode.IsHex(47) { pass = pass + 1 }   // '/' — before '0'

	// IsControl.
	if unicode.IsControl(0) { pass = pass + 1 }    // NUL
	if unicode.IsControl(9) { pass = pass + 1 }    // tab
	if unicode.IsControl(10) { pass = pass + 1 }   // LF
	if unicode.IsControl(31) { pass = pass + 1 }   // last C0
	if unicode.IsControl(127) { pass = pass + 1 }  // DEL
	if !unicode.IsControl(32) { pass = pass + 1 }  // space (printable)
	if !unicode.IsControl(65) { pass = pass + 1 }  // 'A' (printable)

	// IsPunct.
	if unicode.IsPunct(33) { pass = pass + 1 }    // '!'
	if unicode.IsPunct(46) { pass = pass + 1 }    // '.'
	if unicode.IsPunct(64) { pass = pass + 1 }    // '@'
	if unicode.IsPunct(126) { pass = pass + 1 }   // '~'
	if !unicode.IsPunct(65) { pass = pass + 1 }   // 'A' — letter
	if !unicode.IsPunct(48) { pass = pass + 1 }   // '0' — digit
	if !unicode.IsPunct(32) { pass = pass + 1 }   // space — not printable-with-glyph
	if !unicode.IsPunct(127) { pass = pass + 1 }  // DEL — not printable
	if !unicode.IsPunct(0) { pass = pass + 1 }    // NUL

	log.Println("pass=%d", pass)
	if pass == 26 { ret 42 }
	ret 0
}
