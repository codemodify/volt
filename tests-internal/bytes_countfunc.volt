package main
import "log"
import "bytes"

fun isDigit(b byte) bool {
	if b < 48 { ret false }
	if b > 57 { ret false }
	ret true
}

fun isUpper(b byte) bool {
	if b < 65 { ret false }
	if b > 90 { ret false }
	ret true
}

fun isControl(b byte) bool {
	if b < 32 { ret true }
	if b == 127 { ret true }
	ret false
}

fun isAny(b byte) bool {
	if b == 0 { ret true }
	ret true
}

fun isNone(b byte) bool {
	if b == 0 { ret false }
	ret false
}

fun main() int {
	var pass int = 0

	// Empty → 0.
	var e []byte = new(0) []byte {}
	if bytes.CountFunc(e, isDigit) == 0 { pass = pass + 1 }

	// Digits.
	var s1 []byte = new(8) []byte { 104, 101, 108, 108, 111, 49, 50, 51 }   // hello123
	if bytes.CountFunc(s1, isDigit) == 3 { pass = pass + 1 }

	var s2 []byte = new(3) []byte { 97, 98, 99 }
	if bytes.CountFunc(s2, isDigit) == 0 { pass = pass + 1 }

	var s3 []byte = new(5) []byte { 49, 50, 51, 52, 53 }
	if bytes.CountFunc(s3, isDigit) == 5 { pass = pass + 1 }

	// Uppercase.
	var s4 []byte = new(11) []byte { 72, 101, 108, 108, 111, 32, 87, 111, 114, 108, 100 }   // "Hello World"
	if bytes.CountFunc(s4, isUpper) == 2 { pass = pass + 1 }

	var s5 []byte = new(5) []byte { 72, 69, 76, 76, 79 }   // HELLO
	if bytes.CountFunc(s5, isUpper) == 5 { pass = pass + 1 }

	// Control bytes (a common bytes use case: scan binary payload).
	var s6 []byte = new(5) []byte { 104, 10, 105, 9, 13 }
	if bytes.CountFunc(s6, isControl) == 3 { pass = pass + 1 }

	var s7 []byte = new(3) []byte { 97, 98, 99 }
	if bytes.CountFunc(s7, isControl) == 0 { pass = pass + 1 }

	// DEL (127) is control.
	var s8 []byte = new(2) []byte { 97, 127 }
	if bytes.CountFunc(s8, isControl) == 1 { pass = pass + 1 }

	// Always-true → len(s).
	var s9 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	if bytes.CountFunc(s9, isAny) == 5 { pass = pass + 1 }

	// Always-false → 0.
	var s10 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	if bytes.CountFunc(s10, isNone) == 0 { pass = pass + 1 }

	// High-bit bytes (binary payload — wouldn't fit cleanly into a string).
	var s11 []byte = new(4) []byte { 200, 201, 50, 202 }
	if bytes.CountFunc(s11, isDigit) == 1 { pass = pass + 1 }

	// CountByte sanity check.
	var s12 []byte = new(5) []byte { 97, 98, 97, 99, 97 }
	if bytes.CountByte(s12, 97) == 3 { pass = pass + 1 }
	if bytes.CountByte(s12, 98) == 1 { pass = pass + 1 }
	if bytes.CountByte(s12, 100) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
