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

fun main() int {
	var pass int = 0

	// Empty.
	var e []byte = new(0) []byte {}
	var r1 []byte = bytes.Left(e, 5)
	var e1 []byte = new(0) []byte {}
	if bytesEq(r1, e1) { pass = pass + 1 }

	var e2 []byte = new(0) []byte {}
	var r2 []byte = bytes.Right(e2, 5)
	var e2b []byte = new(0) []byte {}
	if bytesEq(r2, e2b) { pass = pass + 1 }

	// n <= 0.
	var s1 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	var r3 []byte = bytes.Left(s1, 0)
	var e3 []byte = new(0) []byte {}
	if bytesEq(r3, e3) { pass = pass + 1 }

	var s2 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	var r4 []byte = bytes.Left(s2, -2)
	var e4 []byte = new(0) []byte {}
	if bytesEq(r4, e4) { pass = pass + 1 }

	var s3 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	var r5 []byte = bytes.Right(s3, 0)
	var e5 []byte = new(0) []byte {}
	if bytesEq(r5, e5) { pass = pass + 1 }

	// Take prefix.
	var s4 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	var r6 []byte = bytes.Left(s4, 3)
	var e6 []byte = new(3) []byte { 1, 2, 3 }
	if bytesEq(r6, e6) { pass = pass + 1 }

	var s5 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	var r7 []byte = bytes.Left(s5, 1)
	var e7 []byte = new(1) []byte { 1 }
	if bytesEq(r7, e7) { pass = pass + 1 }

	// Take suffix.
	var s6 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	var r8 []byte = bytes.Right(s6, 3)
	var e8 []byte = new(3) []byte { 3, 4, 5 }
	if bytesEq(r8, e8) { pass = pass + 1 }

	var s7 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	var r9 []byte = bytes.Right(s7, 1)
	var e9 []byte = new(1) []byte { 5 }
	if bytesEq(r9, e9) { pass = pass + 1 }

	// n >= len → full copy.
	var s8 []byte = new(3) []byte { 7, 8, 9 }
	var r10 []byte = bytes.Left(s8, 10)
	var e10 []byte = new(3) []byte { 7, 8, 9 }
	if bytesEq(r10, e10) { pass = pass + 1 }

	var s9 []byte = new(3) []byte { 7, 8, 9 }
	var r11 []byte = bytes.Right(s9, 10)
	var e11 []byte = new(3) []byte { 7, 8, 9 }
	if bytesEq(r11, e11) { pass = pass + 1 }

	// n == len.
	var s10 []byte = new(3) []byte { 7, 8, 9 }
	var r12 []byte = bytes.Left(s10, 3)
	var e12 []byte = new(3) []byte { 7, 8, 9 }
	if bytesEq(r12, e12) { pass = pass + 1 }

	var s11 []byte = new(3) []byte { 7, 8, 9 }
	var r13 []byte = bytes.Right(s11, 3)
	var e13 []byte = new(3) []byte { 7, 8, 9 }
	if bytesEq(r13, e13) { pass = pass + 1 }

	// High-bit bytes survive (no sign-extension issues for byte storage).
	var s12 []byte = new(4) []byte { 200, 201, 202, 203 }
	var r14 []byte = bytes.Left(s12, 2)
	var e14 []byte = new(2) []byte { 200, 201 }
	if bytesEq(r14, e14) { pass = pass + 1 }

	var s13 []byte = new(4) []byte { 200, 201, 202, 203 }
	var r15 []byte = bytes.Right(s13, 2)
	var e15 []byte = new(2) []byte { 202, 203 }
	if bytesEq(r15, e15) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
