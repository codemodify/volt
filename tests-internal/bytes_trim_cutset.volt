package main
import "log"
import "bytes"

// Positive test: bytes.Trim / TrimLeft / TrimRight. Cutset-based
// trim helpers parallel to the strings.* counterparts.

fun main() int {
	var pass int = 0

	// TrimLeft: strip leading bytes in cutset.
	// "xxhello" → "hello" (bytes 120, 120, 104, 101, 108, 108, 111)
	var s1 []byte = new(7) []byte{120, 120, 104, 101, 108, 108, 111}
	var c1 []byte = new(1) []byte{120}
	var r1 []byte = bytes.TrimLeft(s1, c1)
	if len(r1) == 5 { pass = pass + 1 }
	if r1[0] == 104 { pass = pass + 1 }

	// TrimLeft: no leading match → unchanged copy.
	var s2 []byte = new(3) []byte{1, 2, 3}
	var c2 []byte = new(1) []byte{99}
	var r2 []byte = bytes.TrimLeft(s2, c2)
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 1 { pass = pass + 1 }

	// TrimLeft: all match → empty result.
	var s3 []byte = new(3) []byte{1, 1, 1}
	var c3 []byte = new(1) []byte{1}
	var r3 []byte = bytes.TrimLeft(s3, c3)
	if len(r3) == 0 { pass = pass + 1 }

	// TrimRight: strip trailing bytes in cutset.
	// "helloxx" → "hello"
	var s4 []byte = new(7) []byte{104, 101, 108, 108, 111, 120, 120}
	var c4 []byte = new(1) []byte{120}
	var r4 []byte = bytes.TrimRight(s4, c4)
	if len(r4) == 5 { pass = pass + 1 }
	if r4[4] == 111 { pass = pass + 1 }

	// TrimRight: no trailing match → unchanged.
	var s5 []byte = new(3) []byte{1, 2, 3}
	var c5 []byte = new(1) []byte{99}
	var r5 []byte = bytes.TrimRight(s5, c5)
	if len(r5) == 3 { pass = pass + 1 }

	// Trim: strip from both ends with multi-byte cutset.
	// "xxxhelloxx" with cutset "x" → "hello"
	var s6 []byte = new(10) []byte{120, 120, 120, 104, 101, 108, 108, 111, 120, 120}
	var c6 []byte = new(1) []byte{120}
	var r6 []byte = bytes.Trim(s6, c6)
	if len(r6) == 5 { pass = pass + 1 }
	if r6[0] == 104 { pass = pass + 1 }
	if r6[4] == 111 { pass = pass + 1 }

	// Trim: multi-byte cutset (any of: 32 space, 9 tab).
	// " \thi\t " → "hi"
	var s7 []byte = new(6) []byte{32, 9, 104, 105, 9, 32}
	var c7 []byte = new(2) []byte{32, 9}
	var r7 []byte = bytes.Trim(s7, c7)
	if len(r7) == 2 { pass = pass + 1 }
	if r7[0] == 104 { pass = pass + 1 }
	if r7[1] == 105 { pass = pass + 1 }

	// Trim: empty cutset → unchanged copy.
	var s8 []byte = new(3) []byte{1, 2, 3}
	var c8 []byte = new(0) []byte{}
	var r8 []byte = bytes.Trim(s8, c8)
	if len(r8) == 3 { pass = pass + 1 }
	if r8[0] == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
