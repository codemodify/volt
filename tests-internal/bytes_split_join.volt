package main
import "log"
import "bytes"

// Positive test: bytes.Split / bytes.Join over `[][]byte`. Exercises
// the LANG.8 slice-of-slice indexing widening — without it Split's
// result couldn't be read back per-byte.

fun main() int {
	var pass int = 0

	// Split "A,B,C" by ","
	// 'A'=65, ','=44, 'B'=66, 'C'=67
	var s1 []byte = new(5) []byte{65, 44, 66, 44, 67}
	var sep1 []byte = new(1) []byte{44}
	var p1 [][]byte = bytes.Split(s1, sep1)
	if len(p1) == 3 { pass = pass + 1 }
	if len(p1[0]) == 1 { pass = pass + 1 }
	if p1[0][0] == 65 { pass = pass + 1 }
	if p1[1][0] == 66 { pass = pass + 1 }
	if p1[2][0] == 67 { pass = pass + 1 }

	// Split with multi-byte separator.
	// "ABXYAB" → ["", "XY", ""] when sep is "AB"
	var s2 []byte = new(6) []byte{65, 66, 88, 89, 65, 66}
	var sep2 []byte = new(2) []byte{65, 66}
	var p2 [][]byte = bytes.Split(s2, sep2)
	if len(p2) == 3 { pass = pass + 1 }
	if len(p2[0]) == 0 { pass = pass + 1 }
	if len(p2[1]) == 2 { pass = pass + 1 }
	if p2[1][0] == 88 { pass = pass + 1 }
	if len(p2[2]) == 0 { pass = pass + 1 }

	// Sep not in s → single-element result.
	var s3 []byte = new(3) []byte{1, 2, 3}
	var sep3 []byte = new(1) []byte{99}
	var p3 [][]byte = bytes.Split(s3, sep3)
	if len(p3) == 1 { pass = pass + 1 }
	if len(p3[0]) == 3 { pass = pass + 1 }
	if p3[0][2] == 3 { pass = pass + 1 }

	// Join: opposite of Split.
	var a []byte = new(1) []byte{65}
	var b []byte = new(1) []byte{66}
	var cc []byte = new(1) []byte{67}
	var parts [][]byte = new(3) [][]byte{a, b, cc}
	var sep4 []byte = new(1) []byte{44}
	var joined []byte = bytes.Join(parts, sep4)
	if len(joined) == 5 { pass = pass + 1 }
	if joined[0] == 65 { pass = pass + 1 }
	if joined[1] == 44 { pass = pass + 1 }
	if joined[2] == 66 { pass = pass + 1 }
	if joined[4] == 67 { pass = pass + 1 }

	// Join with empty separator.
	var x []byte = new(2) []byte{1, 2}
	var y []byte = new(2) []byte{3, 4}
	var parts2 [][]byte = new(2) [][]byte{x, y}
	var emptySep []byte = new(0) []byte{}
	var joined2 []byte = bytes.Join(parts2, emptySep)
	if len(joined2) == 4 { pass = pass + 1 }
	if joined2[2] == 3 { pass = pass + 1 }

	// Join of empty parts.
	var empty [][]byte = new(0) [][]byte{}
	var anySep []byte = new(1) []byte{0}
	var joined3 []byte = bytes.Join(empty, anySep)
	if len(joined3) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
