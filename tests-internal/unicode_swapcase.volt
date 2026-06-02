package main
import "log"
import "unicode"

fun main() int {
	var pass int = 0

	// Upper → lower.
	if unicode.SwapCase(65) == 97 { pass = pass + 1 }     // A → a
	if unicode.SwapCase(90) == 122 { pass = pass + 1 }    // Z → z

	// Lower → upper.
	if unicode.SwapCase(97) == 65 { pass = pass + 1 }     // a → A
	if unicode.SwapCase(122) == 90 { pass = pass + 1 }    // z → Z

	// Non-letter pass-through.
	if unicode.SwapCase(48) == 48 { pass = pass + 1 }     // '0'
	if unicode.SwapCase(57) == 57 { pass = pass + 1 }     // '9'
	if unicode.SwapCase(32) == 32 { pass = pass + 1 }     // space
	if unicode.SwapCase(10) == 10 { pass = pass + 1 }     // newline
	if unicode.SwapCase(64) == 64 { pass = pass + 1 }     // '@' just before 'A'
	if unicode.SwapCase(91) == 91 { pass = pass + 1 }     // '[' just after 'Z'
	if unicode.SwapCase(96) == 96 { pass = pass + 1 }     // '`' just before 'a'
	if unicode.SwapCase(123) == 123 { pass = pass + 1 }   // '{' just after 'z'
	if unicode.SwapCase(0) == 0 { pass = pass + 1 }       // NUL

	// Double-swap is identity for ALL bytes.
	var allId bool = true
	for i := 0; i < 128; i++ {
		var b byte = i
		if unicode.SwapCase(unicode.SwapCase(b)) != b { allId = false }
	}
	if allId { pass = pass + 1 }

	// Specific case-pair round-trips.
	if unicode.SwapCase(unicode.SwapCase(65)) == 65 { pass = pass + 1 }
	if unicode.SwapCase(unicode.SwapCase(97)) == 97 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
