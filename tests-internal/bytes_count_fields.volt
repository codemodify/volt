package main
import "log"
import "bytes"

// Positive test: bytes.Count + bytes.Fields. Count returns non-
// overlapping occurrences; Fields splits on runs of whitespace.

fun main() int {
	var pass int = 0

	// Count: "AAAA" with sep "AA" → 2 (non-overlapping).
	var s1 []byte = new(4) []byte{65, 65, 65, 65}
	var sep1 []byte = new(2) []byte{65, 65}
	if bytes.Count(s1, sep1) == 2 { pass = pass + 1 }

	// Count: no occurrences.
	var s2 []byte = new(3) []byte{1, 2, 3}
	var sep2 []byte = new(1) []byte{99}
	if bytes.Count(s2, sep2) == 0 { pass = pass + 1 }

	// Count: single occurrence.
	var s3 []byte = new(5) []byte{1, 2, 3, 4, 5}
	var sep3 []byte = new(2) []byte{3, 4}
	if bytes.Count(s3, sep3) == 1 { pass = pass + 1 }

	// Count: empty sep → 0.
	var s4 []byte = new(3) []byte{1, 2, 3}
	var sep4 []byte = new(0) []byte{}
	if bytes.Count(s4, sep4) == 0 { pass = pass + 1 }

	// Count: sep longer than s → 0.
	var s5 []byte = new(2) []byte{1, 2}
	var sep5 []byte = new(3) []byte{1, 2, 3}
	if bytes.Count(s5, sep5) == 0 { pass = pass + 1 }

	// Fields: "  hi  world  " → ["hi", "world"]
	// bytes 32 32 104 105 32 32 119 111 114 108 100 32 32
	var s6 []byte = new(13) []byte{32, 32, 104, 105, 32, 32, 119, 111, 114, 108, 100, 32, 32}
	var f1 [][]byte = bytes.Fields(s6)
	if len(f1) == 2 { pass = pass + 1 }
	if len(f1[0]) == 2 { pass = pass + 1 }
	if f1[0][0] == 104 { pass = pass + 1 }
	if f1[0][1] == 105 { pass = pass + 1 }
	if len(f1[1]) == 5 { pass = pass + 1 }
	if f1[1][0] == 119 { pass = pass + 1 }
	if f1[1][4] == 100 { pass = pass + 1 }

	// Fields: all-whitespace → empty result.
	var s7 []byte = new(4) []byte{32, 9, 10, 13}
	var f2 [][]byte = bytes.Fields(s7)
	if len(f2) == 0 { pass = pass + 1 }

	// Fields: empty input → empty result.
	var s8 []byte = new(0) []byte{}
	var f3 [][]byte = bytes.Fields(s8)
	if len(f3) == 0 { pass = pass + 1 }

	// Fields: single token.
	var s9 []byte = new(3) []byte{65, 66, 67}
	var f4 [][]byte = bytes.Fields(s9)
	if len(f4) == 1 { pass = pass + 1 }
	if f4[0][2] == 67 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
