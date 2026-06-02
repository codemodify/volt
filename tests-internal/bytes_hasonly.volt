package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// Empty s → true (vacuous).
	var e []byte = new(0) []byte {}
	var ab3 []byte = new(3) []byte { 97, 98, 99 }
	if bytes.HasOnly(e, ab3) { pass = pass + 1 }

	// Both empty → true.
	var e2 []byte = new(0) []byte {}
	var ec []byte = new(0) []byte {}
	if bytes.HasOnly(e2, ec) { pass = pass + 1 }

	// Empty chars + non-empty s → false.
	var s1 []byte = new(1) []byte { 97 }
	var ec2 []byte = new(0) []byte {}
	if !bytes.HasOnly(s1, ec2) { pass = pass + 1 }

	// All bytes in alphabet.
	var s2 []byte = new(3) []byte { 97, 98, 99 }
	var ch2 []byte = new(4) []byte { 97, 98, 99, 100 }
	if bytes.HasOnly(s2, ch2) { pass = pass + 1 }

	var s3 []byte = new(3) []byte { 97, 97, 97 }
	var ch3 []byte = new(1) []byte { 97 }
	if bytes.HasOnly(s3, ch3) { pass = pass + 1 }

	// One byte outside alphabet.
	var s4 []byte = new(4) []byte { 97, 98, 99, 100 }
	var ch4 []byte = new(3) []byte { 97, 98, 99 }
	if !bytes.HasOnly(s4, ch4) { pass = pass + 1 }

	var s5 []byte = new(3) []byte { 97, 120, 99 }
	var ch5 []byte = new(3) []byte { 97, 98, 99 }
	if !bytes.HasOnly(s5, ch5) { pass = pass + 1 }

	// Repeated chars in alphabet don't affect membership.
	var s6 []byte = new(3) []byte { 97, 98, 99 }
	var ch6 []byte = new(6) []byte { 97, 97, 98, 98, 99, 99 }
	if bytes.HasOnly(s6, ch6) { pass = pass + 1 }

	// Digits-only whitelist (binary payload of '0'..'9' = 48..57).
	var s7 []byte = new(5) []byte { 49, 50, 51, 52, 53 }
	var ch7 []byte = new(10) []byte { 48, 49, 50, 51, 52, 53, 54, 55, 56, 57 }
	if bytes.HasOnly(s7, ch7) { pass = pass + 1 }

	var s8 []byte = new(5) []byte { 49, 50, 97, 52, 53 }
	var ch8 []byte = new(10) []byte { 48, 49, 50, 51, 52, 53, 54, 55, 56, 57 }
	if !bytes.HasOnly(s8, ch8) { pass = pass + 1 }

	// Single-byte self-membership.
	var s9 []byte = new(1) []byte { 97 }
	var ch9 []byte = new(1) []byte { 97 }
	if bytes.HasOnly(s9, ch9) { pass = pass + 1 }

	var s10 []byte = new(1) []byte { 97 }
	var ch10 []byte = new(1) []byte { 98 }
	if !bytes.HasOnly(s10, ch10) { pass = pass + 1 }

	// High-bit bytes (sign-extension dodge via & 255 in impl).
	var s11 []byte = new(3) []byte { 200, 201, 202 }
	var ch11 []byte = new(3) []byte { 200, 201, 202 }
	if bytes.HasOnly(s11, ch11) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
