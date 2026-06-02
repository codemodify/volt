package main
import "log"
import "bytes"

fun bytesEq(a []byte, b []byte) bool {
	if len(a) != len(b) { ret false }
	for i := 0; i < len(a); i++ {
		if a[i] != b[i] { ret false }
	}
	ret true
}

// strBytes turns a string literal into []byte by char copy (for test fixtures).
fun strBytes(s string) []byte {
	var n int = len(s)
	var out []byte = new(n) []byte {}
	for i := 0; i < n; i++ { out[i] = s[i] }
	ret out
}

fun main() int {
	var pass int = 0

	// Empty.
	var e []byte = strBytes("")
	var r1 []byte = bytes.HeadLines(e, 5)
	if len(r1) == 0 { pass = pass + 1 }
	var e2 []byte = strBytes("")
	var r2 []byte = bytes.TailLines(e2, 5)
	if len(r2) == 0 { pass = pass + 1 }

	// n <= 0 → empty.
	var s1 []byte = strBytes("a\nb\nc")
	var r3 []byte = bytes.HeadLines(s1, 0)
	if len(r3) == 0 { pass = pass + 1 }
	var s2 []byte = strBytes("a\nb\nc")
	var r4 []byte = bytes.HeadLines(s2, -3)
	if len(r4) == 0 { pass = pass + 1 }

	// Take first 2 of 3 lines.
	var s3 []byte = strBytes("a\nb\nc")
	var r5 []byte = bytes.HeadLines(s3, 2)
	var e5 []byte = strBytes("a\nb")
	if bytesEq(r5, e5) { pass = pass + 1 }

	// Take last 2 of 3 lines.
	var s4 []byte = strBytes("a\nb\nc")
	var r6 []byte = bytes.TailLines(s4, 2)
	var e6 []byte = strBytes("b\nc")
	if bytesEq(r6, e6) { pass = pass + 1 }

	// n >= line-count → all.
	var s5 []byte = strBytes("a\nb")
	var r7 []byte = bytes.HeadLines(s5, 99)
	var e7 []byte = strBytes("a\nb")
	if bytesEq(r7, e7) { pass = pass + 1 }

	var s6 []byte = strBytes("a\nb")
	var r8 []byte = bytes.TailLines(s6, 99)
	var e8 []byte = strBytes("a\nb")
	if bytesEq(r8, e8) { pass = pass + 1 }

	// Single-line.
	var s7 []byte = strBytes("only")
	var r9 []byte = bytes.HeadLines(s7, 5)
	var e9 []byte = strBytes("only")
	if bytesEq(r9, e9) { pass = pass + 1 }

	// CRLF normalization.
	var s8 []byte = strBytes("a\r\nb\r\nc")
	var r10 []byte = bytes.HeadLines(s8, 2)
	var e10 []byte = strBytes("a\nb")
	if bytesEq(r10, e10) { pass = pass + 1 }

	var s9 []byte = strBytes("a\r\nb\r\nc")
	var r11 []byte = bytes.TailLines(s9, 1)
	var e11 []byte = strBytes("c")
	if bytesEq(r11, e11) { pass = pass + 1 }

	// `head -5` style use case on a 10-line buffer.
	var ten []byte = strBytes("L1\nL2\nL3\nL4\nL5\nL6\nL7\nL8\nL9\nL10")
	var r12 []byte = bytes.HeadLines(ten, 5)
	var e12 []byte = strBytes("L1\nL2\nL3\nL4\nL5")
	if bytesEq(r12, e12) { pass = pass + 1 }

	var ten2 []byte = strBytes("L1\nL2\nL3\nL4\nL5\nL6\nL7\nL8\nL9\nL10")
	var r13 []byte = bytes.TailLines(ten2, 3)
	var e13 []byte = strBytes("L8\nL9\nL10")
	if bytesEq(r13, e13) { pass = pass + 1 }

	// High-bit byte preservation.
	var s10 []byte = new(7) []byte { 200, 10, 201, 10, 202 }
	var r14 []byte = bytes.HeadLines(s10, 2)
	var e14 []byte = new(3) []byte { 200, 10, 201 }
	if bytesEq(r14, e14) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
