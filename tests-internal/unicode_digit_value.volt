package main
import "log"
import "unicode"

fun main() int {
	var pass int = 0

	// DigitValue — each digit maps correctly.
	if unicode.DigitValue(48) == 0 { pass = pass + 1 }
	if unicode.DigitValue(49) == 1 { pass = pass + 1 }
	if unicode.DigitValue(53) == 5 { pass = pass + 1 }
	if unicode.DigitValue(57) == 9 { pass = pass + 1 }

	// DigitValue — non-digit returns -1.
	if unicode.DigitValue(65) == -1 { pass = pass + 1 }   // 'A'
	if unicode.DigitValue(97) == -1 { pass = pass + 1 }   // 'a'
	if unicode.DigitValue(47) == -1 { pass = pass + 1 }   // '/' just before '0'
	if unicode.DigitValue(58) == -1 { pass = pass + 1 }   // ':' just after '9'
	if unicode.DigitValue(32) == -1 { pass = pass + 1 }   // space
	if unicode.DigitValue(0) == -1 { pass = pass + 1 }    // NUL

	// HexDigitValue — decimal digits.
	if unicode.HexDigitValue(48) == 0 { pass = pass + 1 }
	if unicode.HexDigitValue(57) == 9 { pass = pass + 1 }

	// HexDigitValue — lowercase a..f.
	if unicode.HexDigitValue(97) == 10 { pass = pass + 1 }   // 'a'
	if unicode.HexDigitValue(98) == 11 { pass = pass + 1 }   // 'b'
	if unicode.HexDigitValue(102) == 15 { pass = pass + 1 }  // 'f'

	// HexDigitValue — uppercase A..F.
	if unicode.HexDigitValue(65) == 10 { pass = pass + 1 }   // 'A'
	if unicode.HexDigitValue(70) == 15 { pass = pass + 1 }   // 'F'

	// HexDigitValue — non-hex returns -1.
	if unicode.HexDigitValue(71) == -1 { pass = pass + 1 }   // 'G'
	if unicode.HexDigitValue(103) == -1 { pass = pass + 1 }  // 'g'
	if unicode.HexDigitValue(32) == -1 { pass = pass + 1 }   // space
	if unicode.HexDigitValue(64) == -1 { pass = pass + 1 }   // '@' just before 'A'
	if unicode.HexDigitValue(91) == -1 { pass = pass + 1 }   // '[' just after 'Z'

	// Use case: parse a 4-digit hex \uHHHH.
	var hex string = "00e9"
	var cp int = 0
	var ok bool = true
	for i := 0; i < 4; i++ {
		var v int = unicode.HexDigitValue(hex[i])
		if v < 0 { ok = false }
		cp = cp * 16 + v
	}
	if ok { pass = pass + 1 }
	if cp == 233 { pass = pass + 1 }    // U+00E9 = é

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
