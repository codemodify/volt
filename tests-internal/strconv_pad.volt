package main
import "log"
import "strconv"

fun main() int {
	var pass int = 0

	// FormatHexPad — common widths.
	if strconv.FormatHexPad(255, 4) == "00ff" { pass = pass + 1 }
	if strconv.FormatHexPad(0, 2) == "00" { pass = pass + 1 }
	if strconv.FormatHexPad(15, 2) == "0f" { pass = pass + 1 }
	if strconv.FormatHexPad(16, 2) == "10" { pass = pass + 1 }
	if strconv.FormatHexPad(0xDEAD, 4) == "dead" { pass = pass + 1 }
	if strconv.FormatHexPad(0xBEEF, 8) == "0000beef" { pass = pass + 1 }

	// Width <= len(digits) → unpadded.
	if strconv.FormatHexPad(255, 2) == "ff" { pass = pass + 1 }
	if strconv.FormatHexPad(255, 0) == "ff" { pass = pass + 1 }
	if strconv.FormatHexPad(255, -5) == "ff" { pass = pass + 1 }

	// Negative.
	if strconv.FormatHexPad(-15, 4) == "-000f" { pass = pass + 1 }
	if strconv.FormatHexPad(-1, 2) == "-01" { pass = pass + 1 }

	// MAC-octet style.
	if strconv.FormatHexPad(0xAB, 2) == "ab" { pass = pass + 1 }
	if strconv.FormatHexPad(0xCD, 2) == "cd" { pass = pass + 1 }

	// FormatBinaryPad.
	if strconv.FormatBinaryPad(5, 8) == "00000101" { pass = pass + 1 }
	if strconv.FormatBinaryPad(0, 4) == "0000" { pass = pass + 1 }
	if strconv.FormatBinaryPad(1, 4) == "0001" { pass = pass + 1 }
	if strconv.FormatBinaryPad(15, 4) == "1111" { pass = pass + 1 }
	if strconv.FormatBinaryPad(255, 8) == "11111111" { pass = pass + 1 }
	if strconv.FormatBinaryPad(255, 16) == "0000000011111111" { pass = pass + 1 }

	// Bitmask / flag-field rendering.
	if strconv.FormatBinaryPad(0b10101010, 8) == "10101010" { pass = pass + 1 }

	// Width <= len → unpadded.
	if strconv.FormatBinaryPad(255, 4) == "11111111" { pass = pass + 1 }
	if strconv.FormatBinaryPad(5, 0) == "101" { pass = pass + 1 }

	// Negative.
	if strconv.FormatBinaryPad(-5, 8) == "-00000101" { pass = pass + 1 }
	if strconv.FormatBinaryPad(-1, 4) == "-0001" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
