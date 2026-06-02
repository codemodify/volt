package main
import "log"
import "strconv"

fun main() int {
	var pass int = 0

	// FormatHex.
	if strconv.FormatHex(255) == "ff" { pass = pass + 1 }
	if strconv.FormatHex(0) == "0" { pass = pass + 1 }
	if strconv.FormatHex(16) == "10" { pass = pass + 1 }
	if strconv.FormatHex(3735928559) == "deadbeef" { pass = pass + 1 }
	if strconv.FormatHex(-1) == "-1" { pass = pass + 1 }    // signed

	// FormatBinary.
	if strconv.FormatBinary(0) == "0" { pass = pass + 1 }
	if strconv.FormatBinary(1) == "1" { pass = pass + 1 }
	if strconv.FormatBinary(2) == "10" { pass = pass + 1 }
	if strconv.FormatBinary(10) == "1010" { pass = pass + 1 }
	if strconv.FormatBinary(255) == "11111111" { pass = pass + 1 }

	// FormatOctal.
	if strconv.FormatOctal(0) == "0" { pass = pass + 1 }
	if strconv.FormatOctal(8) == "10" { pass = pass + 1 }
	if strconv.FormatOctal(493) == "755" { pass = pass + 1 }      // 0o755 file mode
	if strconv.FormatOctal(420) == "644" { pass = pass + 1 }      // 0o644 file mode
	if strconv.FormatOctal(511) == "777" { pass = pass + 1 }      // 0o777

	// Cross-checks with FormatInt.
	if strconv.FormatHex(42) == strconv.FormatInt(42, 16) { pass = pass + 1 }
	if strconv.FormatBinary(42) == strconv.FormatInt(42, 2) { pass = pass + 1 }
	if strconv.FormatOctal(42) == strconv.FormatInt(42, 8) { pass = pass + 1 }

	// Round-trip with ParseIntOr.
	if strconv.ParseIntOr(strconv.FormatHex(255), 16, 0) == 255 { pass = pass + 1 }
	if strconv.ParseIntOr(strconv.FormatBinary(10), 2, 0) == 10 { pass = pass + 1 }
	if strconv.ParseIntOr(strconv.FormatOctal(493), 8, 0) == 493 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
