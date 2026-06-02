package main
import "log"
import "strings"
import "bytes"

// Positive test: strings.OnlyHex + bytes.OnlyHex.

fun main() int {
	var pass int = 0

	// strings.OnlyHex — pure hex passes.
	if strings.OnlyHex("deadbeef") == "deadbeef" { pass = pass + 1 }
	if strings.OnlyHex("DEADBEEF") == "DEADBEEF" { pass = pass + 1 }

	// strings.OnlyHex — mixed case preserved.
	if strings.OnlyHex("CafE-Babe") == "CafEBabe" { pass = pass + 1 }

	// strings.OnlyHex — strips spaces and punctuation.
	if strings.OnlyHex("0x1234abcd") == "01234abcd" { pass = pass + 1 }
	if strings.OnlyHex("ff:ee:dd:cc") == "ffeeddcc" { pass = pass + 1 }

	// strings.OnlyHex — pure digits work.
	if strings.OnlyHex("01234567") == "01234567" { pass = pass + 1 }

	// strings.OnlyHex — non-hex letters strip.
	if strings.OnlyHex("xyzABCghi") == "ABC" { pass = pass + 1 }

	// strings.OnlyHex — empty.
	if strings.OnlyHex("") == "" { pass = pass + 1 }

	// strings.OnlyHex — all stripped.
	if strings.OnlyHex("!!@@##") == "" { pass = pass + 1 }
	if strings.OnlyHex("xyzwgh") == "" { pass = pass + 1 }

	// strings.OnlyHex — UTF-8 multi-byte strip (café = c-a-f-é, é = 2 bytes both > 102).
	if strings.OnlyHex("café-deadbeef") == "cafdeadbeef" { pass = pass + 1 }

	// bytes.OnlyHex — basic.
	var b1 []byte = bytes.OnlyHex(new(8) []byte { 100, 101, 97, 100, 98, 101, 101, 102 })   // "deadbeef"
	if len(b1) == 8 { pass = pass + 1 }
	if b1[0] == 100 { pass = pass + 1 }

	// bytes.OnlyHex — strip separators.
	var b2 []byte = bytes.OnlyHex(new(9) []byte { 102, 102, 58, 101, 101, 58, 100, 100, 58 })   // "ff:ee:dd:"
	if len(b2) == 6 { pass = pass + 1 }
	if b2[0] == 102 { pass = pass + 1 }

	// bytes.OnlyHex — empty.
	var b3 []byte = bytes.OnlyHex(new(0) []byte {})
	if len(b3) == 0 { pass = pass + 1 }

	// bytes.OnlyHex — high-bit bytes drop.
	var b4 []byte = bytes.OnlyHex(new(4) []byte { 97, 255, 98, 200 })
	if len(b4) == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
