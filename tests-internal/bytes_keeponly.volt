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

	// Empty chars → empty out.
	var s1 []byte = new(3) []byte { 97, 98, 99 }
	var c1 []byte = new(0) []byte {}
	var r1 []byte = bytes.KeepOnly(s1, c1)
	var e1 []byte = new(0) []byte {}
	if bytesEq(r1, e1) { pass = pass + 1 }

	// Empty s → empty out.
	var s2 []byte = new(0) []byte {}
	var c2 []byte = new(3) []byte { 97, 98, 99 }
	var r2 []byte = bytes.KeepOnly(s2, c2)
	var e2 []byte = new(0) []byte {}
	if bytesEq(r2, e2) { pass = pass + 1 }

	// Both empty → empty out.
	var s3 []byte = new(0) []byte {}
	var c3 []byte = new(0) []byte {}
	var r3 []byte = bytes.KeepOnly(s3, c3)
	var e3 []byte = new(0) []byte {}
	if bytesEq(r3, e3) { pass = pass + 1 }

	// All allowed → unchanged content.
	var s4 []byte = new(3) []byte { 97, 98, 99 }
	var c4 []byte = new(4) []byte { 97, 98, 99, 100 }
	var r4 []byte = bytes.KeepOnly(s4, c4)
	var e4 []byte = new(3) []byte { 97, 98, 99 }
	if bytesEq(r4, e4) { pass = pass + 1 }

	// All disallowed → empty.
	var s5 []byte = new(3) []byte { 120, 121, 122 }
	var c5 []byte = new(3) []byte { 97, 98, 99 }
	var r5 []byte = bytes.KeepOnly(s5, c5)
	var e5 []byte = new(0) []byte {}
	if bytesEq(r5, e5) { pass = pass + 1 }

	// Mixed: keep abc, drop rest.
	var s6 []byte = new(6) []byte { 97, 49, 98, 50, 99, 51 }   // a1b2c3
	var c6 []byte = new(3) []byte { 97, 98, 99 }
	var r6 []byte = bytes.KeepOnly(s6, c6)
	var e6 []byte = new(3) []byte { 97, 98, 99 }
	if bytesEq(r6, e6) { pass = pass + 1 }

	// Order preserved (filter, not sort).
	var s7 []byte = new(6) []byte { 99, 49, 98, 50, 97, 51 }   // c1b2a3
	var c7 []byte = new(3) []byte { 97, 98, 99 }
	var r7 []byte = bytes.KeepOnly(s7, c7)
	var e7 []byte = new(3) []byte { 99, 98, 97 }
	if bytesEq(r7, e7) { pass = pass + 1 }

	// Digits-only (binary payload).
	var s8 []byte = new(11) []byte { 112, 104, 111, 110, 101, 32, 49, 50, 51, 52, 53 }   // "phone 12345"
	var c8 []byte = new(10) []byte { 48, 49, 50, 51, 52, 53, 54, 55, 56, 57 }
	var r8 []byte = bytes.KeepOnly(s8, c8)
	var e8 []byte = new(5) []byte { 49, 50, 51, 52, 53 }
	if bytesEq(r8, e8) { pass = pass + 1 }

	// Repeated chars in alphabet don't change result.
	var s9 []byte = new(5) []byte { 104, 101, 108, 108, 111 }   // "hello"
	var c9 []byte = new(8) []byte { 97, 97, 98, 98, 101, 101, 108, 108 }
	var r9 []byte = bytes.KeepOnly(s9, c9)
	var e9 []byte = new(3) []byte { 101, 108, 108 }
	if bytesEq(r9, e9) { pass = pass + 1 }

	// High-bit bytes survive via & 255 dodge.
	var s10 []byte = new(3) []byte { 200, 50, 201 }
	var c10 []byte = new(2) []byte { 200, 201 }
	var r10 []byte = bytes.KeepOnly(s10, c10)
	var e10 []byte = new(2) []byte { 200, 201 }
	if bytesEq(r10, e10) { pass = pass + 1 }

	// Cross-property: HasOnly(KeepOnly(s, c), c) is true.
	var s11 []byte = new(6) []byte { 97, 49, 98, 50, 99, 51 }
	var c11 []byte = new(3) []byte { 97, 98, 99 }
	var r11 []byte = bytes.KeepOnly(s11, c11)
	var c11b []byte = new(3) []byte { 97, 98, 99 }
	if bytes.HasOnly(r11, c11b) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
