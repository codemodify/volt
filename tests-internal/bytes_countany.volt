package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// "hello world" — count vowels.
	var hw []byte = new(11) []byte { 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100 }
	var vow []byte = new(5) []byte { 97, 101, 105, 111, 117 }     // "aeiou"
	if bytes.CountAny(hw, vow) == 3 { pass = pass + 1 }

	// "abc123def456" — count digits.
	var ad []byte = new(12) []byte { 97, 98, 99, 49, 50, 51, 100, 101, 102, 52, 53, 54 }
	var digs []byte = new(10) []byte { 48, 49, 50, 51, 52, 53, 54, 55, 56, 57 }
	if bytes.CountAny(ad, digs) == 6 { pass = pass + 1 }

	// All-match.
	var aaaa []byte = new(4) []byte { 97, 97, 97, 97 }
	var a1 []byte = new(1) []byte { 97 }
	if bytes.CountAny(aaaa, a1) == 4 { pass = pass + 1 }
	var abc []byte = new(3) []byte { 97, 98, 99 }
	if bytes.CountAny(aaaa, abc) == 4 { pass = pass + 1 }

	// None match.
	var hello []byte = new(5) []byte { 104, 101, 108, 108, 111 }
	var xyz []byte = new(3) []byte { 120, 121, 122 }
	if bytes.CountAny(hello, xyz) == 0 { pass = pass + 1 }

	// Empty inputs.
	var emp []byte = new(0) []byte {}
	if bytes.CountAny(emp, abc) == 0 { pass = pass + 1 }
	if bytes.CountAny(hello, emp) == 0 { pass = pass + 1 }
	if bytes.CountAny(emp, emp) == 0 { pass = pass + 1 }

	// Repeated chars in set — no double-count.
	var helloR []byte = new(5) []byte { 104, 101, 108, 108, 111 }
	var ll []byte = new(2) []byte { 108, 108 }
	if bytes.CountAny(helloR, ll) == 2 { pass = pass + 1 }   // l × 2

	// Whitespace count.
	var ws []byte = new(8) []byte { 97, 32, 98, 32, 99, 9, 100, 10 }
	var wsSet []byte = new(3) []byte { 32, 9, 10 }
	if bytes.CountAny(ws, wsSet) == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
