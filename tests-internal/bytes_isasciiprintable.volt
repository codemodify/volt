package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// Empty.
	var empty []byte = new(0) []byte {}
	if bytes.IsAsciiPrintable(empty) { pass = pass + 1 }

	// All printable.
	var ok1 []byte = new(5) []byte { 104, 101, 108, 108, 111 }   // "hello"
	if bytes.IsAsciiPrintable(ok1) { pass = pass + 1 }

	// "Hello, World!" range of printables.
	var hw []byte = new(13) []byte { 72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33 }
	if bytes.IsAsciiPrintable(hw) { pass = pass + 1 }

	// Boundary: space (32) and tilde (126).
	var sp []byte = new(1) []byte { 32 }
	var ti []byte = new(1) []byte { 126 }
	if bytes.IsAsciiPrintable(sp) { pass = pass + 1 }
	if bytes.IsAsciiPrintable(ti) { pass = pass + 1 }

	// Just below space (0x1F = 31) fails.
	var below []byte = new(1) []byte { 31 }
	if !bytes.IsAsciiPrintable(below) { pass = pass + 1 }

	// DEL (0x7F = 127) fails.
	var del []byte = new(1) []byte { 127 }
	if !bytes.IsAsciiPrintable(del) { pass = pass + 1 }

	// Newline / tab / NUL fail.
	var nl []byte = new(1) []byte { 10 }
	var tab []byte = new(1) []byte { 9 }
	var nul []byte = new(1) []byte { 0 }
	if !bytes.IsAsciiPrintable(nl) { pass = pass + 1 }
	if !bytes.IsAsciiPrintable(tab) { pass = pass + 1 }
	if !bytes.IsAsciiPrintable(nul) { pass = pass + 1 }

	// Embedded NL fails.
	var emb []byte = new(3) []byte { 97, 10, 98 }
	if !bytes.IsAsciiPrintable(emb) { pass = pass + 1 }

	// High-bit fails.
	var utf []byte = new(2) []byte { 195, 169 }    // 0xc3 0xa9 (é)
	if !bytes.IsAsciiPrintable(utf) { pass = pass + 1 }

	var ff []byte = new(1) []byte { 255 }
	if !bytes.IsAsciiPrintable(ff) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
