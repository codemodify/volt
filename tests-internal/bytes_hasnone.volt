package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// Empty s → true (vacuous).
	var e []byte = new(0) []byte {}
	var abc []byte = new(3) []byte { 97, 98, 99 }
	if bytes.HasNone(e, abc) { pass = pass + 1 }

	// Both empty → true.
	var e2 []byte = new(0) []byte {}
	var ec []byte = new(0) []byte {}
	if bytes.HasNone(e2, ec) { pass = pass + 1 }

	// Empty chars + non-empty s → true (nothing forbidden).
	var s1 []byte = new(3) []byte { 97, 98, 99 }
	var ec2 []byte = new(0) []byte {}
	if bytes.HasNone(s1, ec2) { pass = pass + 1 }

	// No overlap → true.
	var s2 []byte = new(3) []byte { 97, 98, 99 }
	var ch2 []byte = new(3) []byte { 100, 101, 102 }
	if bytes.HasNone(s2, ch2) { pass = pass + 1 }

	// Any overlap → false.
	var s3 []byte = new(3) []byte { 97, 98, 99 }
	var ch3 []byte = new(4) []byte { 120, 121, 122, 99 }
	if !bytes.HasNone(s3, ch3) { pass = pass + 1 }

	var s4 []byte = new(3) []byte { 97, 98, 99 }
	var ch4 []byte = new(1) []byte { 97 }
	if !bytes.HasNone(s4, ch4) { pass = pass + 1 }

	// Repeated chars in blacklist don't change result.
	var s5 []byte = new(3) []byte { 97, 98, 99 }
	var ch5 []byte = new(6) []byte { 97, 97, 98, 98, 99, 99 }
	if !bytes.HasNone(s5, ch5) { pass = pass + 1 }

	// Control-byte blacklist: no LF/CR/HT.
	var s6 []byte = new(5) []byte { 104, 101, 108, 108, 111 }
	var ch6 []byte = new(3) []byte { 10, 13, 9 }
	if bytes.HasNone(s6, ch6) { pass = pass + 1 }

	var s7 []byte = new(6) []byte { 104, 101, 108, 10, 108, 111 }
	var ch7 []byte = new(3) []byte { 10, 13, 9 }
	if !bytes.HasNone(s7, ch7) { pass = pass + 1 }

	// Single-byte self-blacklist.
	var s8 []byte = new(1) []byte { 97 }
	var ch8 []byte = new(1) []byte { 97 }
	if !bytes.HasNone(s8, ch8) { pass = pass + 1 }

	var s9 []byte = new(1) []byte { 97 }
	var ch9 []byte = new(1) []byte { 98 }
	if bytes.HasNone(s9, ch9) { pass = pass + 1 }

	// High-bit bytes via & 255 dodge.
	var s10 []byte = new(3) []byte { 200, 201, 202 }
	var ch10 []byte = new(1) []byte { 200 }
	if !bytes.HasNone(s10, ch10) { pass = pass + 1 }

	var s11 []byte = new(3) []byte { 200, 201, 202 }
	var ch11 []byte = new(1) []byte { 50 }
	if bytes.HasNone(s11, ch11) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
