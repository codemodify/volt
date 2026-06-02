package main
import "log"
import "bytes"

fun isDigit(b byte) bool {
	if b < 48 { ret false }
	if b > 57 { ret false }
	ret true
}
fun isPrintable(b byte) bool {
	if b < 32 { ret false }
	if b > 126 { ret false }
	ret true
}
fun isAlpha(b byte) bool {
	if b >= 65 { if b <= 90 { ret true } }
	if b >= 97 { if b <= 122 { ret true } }
	ret false
}
fun isAny(b byte) bool {
	if b < 0 { ret false }
	ret true
}

fun main() int {
	var pass int = 0

	// Longest digit run in "abc123def4567".
	var s1 []byte = new(13) []byte { 97, 98, 99, 49, 50, 51, 100, 101, 102, 52, 53, 54, 55 }
	if bytes.LongestRunFunc(s1, isDigit) == 4 { pass = pass + 1 }

	// No digit.
	var s2 []byte = new(5) []byte { 104, 101, 108, 108, 111 }   // "hello"
	if bytes.LongestRunFunc(s2, isDigit) == 0 { pass = pass + 1 }

	// All digits.
	var s3 []byte = new(5) []byte { 49, 50, 51, 52, 53 }
	if bytes.LongestRunFunc(s3, isDigit) == 5 { pass = pass + 1 }

	// Longest letter run interrupted.
	if bytes.LongestRunFunc(s1, isAlpha) == 3 { pass = pass + 1 }   // "abc"

	// "Hello\x00\x01World" — longest printable run.
	var s4 []byte = new(12) []byte { 72, 101, 108, 108, 111, 0, 1, 87, 111, 114, 108, 100 }
	if bytes.LongestRunFunc(s4, isPrintable) == 5 { pass = pass + 1 }   // "Hello" or "World"

	// Empty.
	var empty []byte = new(0) []byte {}
	if bytes.LongestRunFunc(empty, isDigit) == 0 { pass = pass + 1 }
	if bytes.LongestRunFunc(empty, isAny) == 0 { pass = pass + 1 }

	// All-match (isAny).
	if bytes.LongestRunFunc(s1, isAny) == 13 { pass = pass + 1 }

	// Run at start.
	var s5 []byte = new(6) []byte { 49, 50, 51, 97, 98, 99 }
	if bytes.LongestRunFunc(s5, isDigit) == 3 { pass = pass + 1 }

	// Run at end.
	var s6 []byte = new(6) []byte { 97, 98, 99, 49, 50, 51 }
	if bytes.LongestRunFunc(s6, isDigit) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
