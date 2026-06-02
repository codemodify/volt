package main
import "log"
import "bytes"

// Positive test: bytes.IndexAny / ContainsAny. Parallel to the
// strings.* counterparts but for []byte slices.

fun main() int {
	var pass int = 0

	// IndexAny: first matching byte.
	// "hello" = 104, 101, 108, 108, 111; chars = "aeiou" → 'e' at index 1
	var s1 []byte = new(5) []byte{104, 101, 108, 108, 111}
	var c1 []byte = new(5) []byte{97, 101, 105, 111, 117}
	if bytes.IndexAny(s1, c1) == 1 { pass = pass + 1 }

	// No match.
	var s2 []byte = new(3) []byte{1, 2, 3}
	var c2 []byte = new(3) []byte{4, 5, 6}
	if bytes.IndexAny(s2, c2) == -1 { pass = pass + 1 }

	// Empty chars → -1.
	var s3 []byte = new(3) []byte{1, 2, 3}
	var c3 []byte = new(0) []byte{}
	if bytes.IndexAny(s3, c3) == -1 { pass = pass + 1 }

	// Empty s → -1.
	var s4 []byte = new(0) []byte{}
	var c4 []byte = new(2) []byte{1, 2}
	if bytes.IndexAny(s4, c4) == -1 { pass = pass + 1 }

	// First byte of s matches.
	var s5 []byte = new(3) []byte{42, 1, 2}
	var c5 []byte = new(2) []byte{42, 99}
	if bytes.IndexAny(s5, c5) == 0 { pass = pass + 1 }

	// ContainsAny: at least one match.
	var s6 []byte = new(5) []byte{1, 2, 3, 4, 5}
	var c6 []byte = new(2) []byte{99, 3}
	if bytes.ContainsAny(s6, c6) { pass = pass + 1 }

	// ContainsAny: no match.
	var s7 []byte = new(3) []byte{1, 2, 3}
	var c7 []byte = new(2) []byte{99, 100}
	if !bytes.ContainsAny(s7, c7) { pass = pass + 1 }

	// ContainsAny: empty chars.
	var s8 []byte = new(3) []byte{1, 2, 3}
	var c8 []byte = new(0) []byte{}
	if !bytes.ContainsAny(s8, c8) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 8 { ret 42 }
	ret 0
}
