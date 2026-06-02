package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// IsNumeric — empty rejected.
	var empty []byte = new(0) []byte {}
	if !bytes.IsNumeric(empty) { pass = pass + 1 }

	// IsNumeric — all digits.
	var d1 []byte = new(3) []byte { 49, 50, 51 }      // "123"
	if bytes.IsNumeric(d1) { pass = pass + 1 }
	var d2 []byte = new(1) []byte { 48 }              // "0"
	if bytes.IsNumeric(d2) { pass = pass + 1 }
	var d3 []byte = new(10) []byte { 48, 49, 50, 51, 52, 53, 54, 55, 56, 57 }   // "0123456789"
	if bytes.IsNumeric(d3) { pass = pass + 1 }

	// IsNumeric — single non-digit disqualifies.
	var bad1 []byte = new(4) []byte { 49, 50, 97, 51 }  // "12a3"
	if !bytes.IsNumeric(bad1) { pass = pass + 1 }
	var bad2 []byte = new(2) []byte { 45, 49 }          // "-1" (minus not digit)
	if !bytes.IsNumeric(bad2) { pass = pass + 1 }

	// IsAlpha — empty rejected.
	if !bytes.IsAlpha(empty) { pass = pass + 1 }

	// IsAlpha — all letters.
	var a1 []byte = new(5) []byte { 104, 101, 108, 108, 111 }      // "hello"
	if bytes.IsAlpha(a1) { pass = pass + 1 }
	var a2 []byte = new(5) []byte { 72, 69, 76, 76, 79 }           // "HELLO"
	if bytes.IsAlpha(a2) { pass = pass + 1 }
	var a3 []byte = new(5) []byte { 72, 101, 108, 108, 111 }       // "Hello" mixed
	if bytes.IsAlpha(a3) { pass = pass + 1 }

	// IsAlpha — digit disqualifies.
	var a4 []byte = new(4) []byte { 97, 98, 49, 99 }               // "ab1c"
	if !bytes.IsAlpha(a4) { pass = pass + 1 }

	// IsAlpha — space disqualifies.
	var a5 []byte = new(3) []byte { 97, 32, 98 }                   // "a b"
	if !bytes.IsAlpha(a5) { pass = pass + 1 }

	// IsAlphanumeric — empty rejected.
	if !bytes.IsAlphanumeric(empty) { pass = pass + 1 }

	// IsAlphanumeric — letters + digits.
	var an1 []byte = new(6) []byte { 97, 98, 99, 49, 50, 51 }      // "abc123"
	if bytes.IsAlphanumeric(an1) { pass = pass + 1 }
	var an2 []byte = new(5) []byte { 100, 50, 56, 102, 50 }        // "d28f2"
	if bytes.IsAlphanumeric(an2) { pass = pass + 1 }

	// IsAlphanumeric — punctuation disqualifies.
	var an3 []byte = new(4) []byte { 97, 49, 33, 98 }              // "a1!b"
	if !bytes.IsAlphanumeric(an3) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
