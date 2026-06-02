package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// "hello\n" → "hello"
	var s1 []byte = new(6) []byte { 104, 101, 108, 108, 111, 10 }
	var r1 []byte = bytes.TrimNewline(s1)
	if len(r1) == 5 { pass = pass + 1 }
	if r1[0] == 104 { pass = pass + 1 }
	if r1[4] == 111 { pass = pass + 1 }

	// "\n" → ""
	var s2 []byte = new(1) []byte { 10 }
	var r2 []byte = bytes.TrimNewline(s2)
	if len(r2) == 0 { pass = pass + 1 }

	// "hello\r\n" → "hello"
	var s3 []byte = new(7) []byte { 104, 101, 108, 108, 111, 13, 10 }
	var r3 []byte = bytes.TrimNewline(s3)
	if len(r3) == 5 { pass = pass + 1 }
	if r3[4] == 111 { pass = pass + 1 }

	// "\r\n" → ""
	var s4 []byte = new(2) []byte { 13, 10 }
	var r4 []byte = bytes.TrimNewline(s4)
	if len(r4) == 0 { pass = pass + 1 }

	// "hello\r" → "hello"
	var s5 []byte = new(6) []byte { 104, 101, 108, 108, 111, 13 }
	var r5 []byte = bytes.TrimNewline(s5)
	if len(r5) == 5 { pass = pass + 1 }

	// "\r" → ""
	var s6 []byte = new(1) []byte { 13 }
	var r6 []byte = bytes.TrimNewline(s6)
	if len(r6) == 0 { pass = pass + 1 }

	// "hello" (no trailing) — copy of length 5.
	var s7 []byte = new(5) []byte { 104, 101, 108, 108, 111 }
	var r7 []byte = bytes.TrimNewline(s7)
	if len(r7) == 5 { pass = pass + 1 }

	// "" → ""
	var s8 []byte = new(0) []byte {}
	var r8 []byte = bytes.TrimNewline(s8)
	if len(r8) == 0 { pass = pass + 1 }

	// "hello\n\n" → "hello\n" (strip-one-only)
	var s9 []byte = new(7) []byte { 104, 101, 108, 108, 111, 10, 10 }
	var r9 []byte = bytes.TrimNewline(s9)
	if len(r9) == 6 { pass = pass + 1 }
	if r9[5] == 10 { pass = pass + 1 }

	// "hello\r\n\r\n" → "hello\r\n"
	var s10 []byte = new(9) []byte { 104, 101, 108, 108, 111, 13, 10, 13, 10 }
	var r10 []byte = bytes.TrimNewline(s10)
	if len(r10) == 7 { pass = pass + 1 }
	if r10[5] == 13 { pass = pass + 1 }
	if r10[6] == 10 { pass = pass + 1 }

	// Embedded newlines preserved.
	// "a\nb\n" → "a\nb"
	var s11 []byte = new(4) []byte { 97, 10, 98, 10 }
	var r11 []byte = bytes.TrimNewline(s11)
	if len(r11) == 3 { pass = pass + 1 }
	if r11[1] == 10 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
