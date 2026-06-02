package main
import "log"
import "bytes"

// Positive test: bytes.OnlyDigits + bytes.OnlyAlphanumeric.

fun main() int {
	var pass int = 0

	// OnlyDigits — basic.
	var d1 []byte = bytes.OnlyDigits(new(15) []byte { 104, 101, 108, 108, 111, 32, 49, 50, 51, 32, 119, 111, 114, 108, 100 })
	// "hello 123 world" → "123"
	if len(d1) == 3 { pass = pass + 1 }
	if d1[0] == 49 { pass = pass + 1 }
	if d1[1] == 50 { pass = pass + 1 }
	if d1[2] == 51 { pass = pass + 1 }

	// OnlyDigits — empty.
	var d2 []byte = bytes.OnlyDigits(new(0) []byte {})
	if len(d2) == 0 { pass = pass + 1 }

	// OnlyDigits — no digits.
	var d3 []byte = bytes.OnlyDigits(new(3) []byte { 97, 98, 99 })   // "abc"
	if len(d3) == 0 { pass = pass + 1 }

	// OnlyDigits — only digits.
	var d4 []byte = bytes.OnlyDigits(new(5) []byte { 49, 50, 51, 52, 53 })
	if len(d4) == 5 { pass = pass + 1 }
	if d4[4] == 53 { pass = pass + 1 }

	// OnlyAlphanumeric — basic mixed.
	var a1 []byte = bytes.OnlyAlphanumeric(new(8) []byte { 72, 105, 45, 84, 104, 101, 114, 101 })   // "Hi-There"
	if len(a1) == 7 { pass = pass + 1 }
	if a1[0] == 72 { pass = pass + 1 }
	if a1[2] == 84 { pass = pass + 1 }

	// OnlyAlphanumeric — empty.
	var a2 []byte = bytes.OnlyAlphanumeric(new(0) []byte {})
	if len(a2) == 0 { pass = pass + 1 }

	// OnlyAlphanumeric — all punctuation.
	var a3 []byte = bytes.OnlyAlphanumeric(new(3) []byte { 33, 64, 35 })   // "!@#"
	if len(a3) == 0 { pass = pass + 1 }

	// OnlyAlphanumeric — preserves case.
	var a4 []byte = bytes.OnlyAlphanumeric(new(6) []byte { 65, 66, 67, 97, 98, 99 })
	if len(a4) == 6 { pass = pass + 1 }
	if a4[0] == 65 { pass = pass + 1 }
	if a4[3] == 97 { pass = pass + 1 }

	// OnlyAlphanumeric — strips whitespace.
	var a5 []byte = bytes.OnlyAlphanumeric(new(5) []byte { 97, 32, 98, 9, 99 })   // "a b\tc"
	if len(a5) == 3 { pass = pass + 1 }
	if a5[0] == 97 { pass = pass + 1 }

	// OnlyAlphanumeric — high-bit bytes drop.
	var a6 []byte = bytes.OnlyAlphanumeric(new(4) []byte { 97, 255, 98, 200 })
	if len(a6) == 2 { pass = pass + 1 }
	if a6[0] == 97 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
