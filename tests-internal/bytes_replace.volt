package main
import "log"
import "bytes"

// Positive test: bytes.Replace — substitute every occurrence of old
// with repl. Parallels strings.Replace for []byte slices.

fun main() int {
	var pass int = 0

	// Simple substitute (1 byte → 1 byte): "ABACA" → "XBXCX".
	var s1 []byte = new(5) []byte{65, 66, 65, 67, 65}
	var old1 []byte = new(1) []byte{65}
	var rep1 []byte = new(1) []byte{88}
	var r1 []byte = bytes.Replace(s1, old1, rep1)
	if len(r1) == 5 { pass = pass + 1 }
	if r1[0] == 88 { pass = pass + 1 }
	if r1[2] == 88 { pass = pass + 1 }
	if r1[4] == 88 { pass = pass + 1 }
	if r1[1] == 66 { pass = pass + 1 }

	// Replace with shorter repl: "AAAA" → with "AA" → "X" → "XX" (2 bytes).
	var s2 []byte = new(4) []byte{65, 65, 65, 65}
	var old2 []byte = new(2) []byte{65, 65}
	var rep2 []byte = new(1) []byte{88}
	var r2 []byte = bytes.Replace(s2, old2, rep2)
	if len(r2) == 2 { pass = pass + 1 }
	if r2[0] == 88 { pass = pass + 1 }
	if r2[1] == 88 { pass = pass + 1 }

	// Replace with longer repl: "AB" with "AB" → "XYZ" → 3 bytes.
	var s3 []byte = new(2) []byte{65, 66}
	var old3 []byte = new(2) []byte{65, 66}
	var rep3 []byte = new(3) []byte{88, 89, 90}
	var r3 []byte = bytes.Replace(s3, old3, rep3)
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == 88 { pass = pass + 1 }
	if r3[2] == 90 { pass = pass + 1 }

	// Not present: returns copy unchanged.
	var s4 []byte = new(3) []byte{1, 2, 3}
	var old4 []byte = new(1) []byte{99}
	var rep4 []byte = new(1) []byte{0}
	var r4 []byte = bytes.Replace(s4, old4, rep4)
	if len(r4) == 3 { pass = pass + 1 }
	if r4[0] == 1 { pass = pass + 1 }
	if r4[2] == 3 { pass = pass + 1 }

	// Empty old: returns copy of s unchanged.
	var s5 []byte = new(3) []byte{1, 2, 3}
	var old5 []byte = new(0) []byte{}
	var rep5 []byte = new(1) []byte{99}
	var r5 []byte = bytes.Replace(s5, old5, rep5)
	if len(r5) == 3 { pass = pass + 1 }
	if r5[0] == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
