package main
import "log"
import "bytes"

// Positive test: bytes scan helpers — Equal, HasPrefix, HasSuffix,
// Index, Contains. Parallel to the corresponding strings.* functions
// but operate on []byte slices.

fun main() int {
	var pass int = 0

	// Equal: same length + same bytes.
	var a []byte = new(3) []byte{1, 2, 3}
	var b []byte = new(3) []byte{1, 2, 3}
	if bytes.Equal(a, b) { pass = pass + 1 }
	var c []byte = new(3) []byte{1, 2, 4}
	var d []byte = new(3) []byte{1, 2, 3}
	if !bytes.Equal(c, d) { pass = pass + 1 }
	var e []byte = new(2) []byte{1, 2}
	var f []byte = new(3) []byte{1, 2, 3}
	if !bytes.Equal(e, f) { pass = pass + 1 }

	// HasPrefix.
	var s1 []byte = new(5) []byte{1, 2, 3, 4, 5}
	var p1 []byte = new(2) []byte{1, 2}
	if bytes.HasPrefix(s1, p1) { pass = pass + 1 }
	var s2 []byte = new(5) []byte{1, 2, 3, 4, 5}
	var p2 []byte = new(2) []byte{2, 3}
	if !bytes.HasPrefix(s2, p2) { pass = pass + 1 }
	// Prefix longer than s → false.
	var s3 []byte = new(2) []byte{1, 2}
	var p3 []byte = new(3) []byte{1, 2, 3}
	if !bytes.HasPrefix(s3, p3) { pass = pass + 1 }

	// HasSuffix.
	var s4 []byte = new(5) []byte{1, 2, 3, 4, 5}
	var sx1 []byte = new(2) []byte{4, 5}
	if bytes.HasSuffix(s4, sx1) { pass = pass + 1 }
	var s5 []byte = new(5) []byte{1, 2, 3, 4, 5}
	var sx2 []byte = new(2) []byte{3, 4}
	if !bytes.HasSuffix(s5, sx2) { pass = pass + 1 }

	// Index.
	var s6 []byte = new(5) []byte{10, 20, 30, 40, 50}
	var sub1 []byte = new(2) []byte{30, 40}
	if bytes.Index(s6, sub1) == 2 { pass = pass + 1 }
	var s7 []byte = new(5) []byte{10, 20, 30, 40, 50}
	var sub2 []byte = new(2) []byte{99, 99}
	if bytes.Index(s7, sub2) == -1 { pass = pass + 1 }
	// Empty sub → 0.
	var s8 []byte = new(3) []byte{1, 2, 3}
	var sub3 []byte = new(0) []byte{}
	if bytes.Index(s8, sub3) == 0 { pass = pass + 1 }

	// Contains.
	var s9 []byte = new(4) []byte{1, 2, 3, 4}
	var sub4 []byte = new(2) []byte{2, 3}
	if bytes.Contains(s9, sub4) { pass = pass + 1 }
	var s10 []byte = new(4) []byte{1, 2, 3, 4}
	var sub5 []byte = new(2) []byte{4, 5}
	if !bytes.Contains(s10, sub5) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
