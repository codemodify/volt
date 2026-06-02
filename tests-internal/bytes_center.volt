package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// Even padding — symmetric.
	var s1 []byte = new(3) []byte { 65, 66, 67 }       // "ABC"
	var r1 []byte = bytes.Center(s1, 7, 32)
	if len(r1) == 7 { pass = pass + 1 }
	if r1[0] == 32 { pass = pass + 1 }   // ' '
	if r1[1] == 32 { pass = pass + 1 }
	if r1[2] == 65 { pass = pass + 1 }   // 'A'
	if r1[4] == 67 { pass = pass + 1 }   // 'C'
	if r1[5] == 32 { pass = pass + 1 }
	if r1[6] == 32 { pass = pass + 1 }

	// Odd padding — extra goes on the right.
	var s2 []byte = new(3) []byte { 88, 89, 90 }       // "XYZ"
	var r2 []byte = bytes.Center(s2, 6, 46)             // '.'
	if len(r2) == 6 { pass = pass + 1 }
	if r2[0] == 46 { pass = pass + 1 }   // left pad 1
	if r2[1] == 88 { pass = pass + 1 }   // 'X' at idx 1
	if r2[3] == 90 { pass = pass + 1 }   // 'Z' at idx 3
	if r2[4] == 46 { pass = pass + 1 }   // right pad
	if r2[5] == 46 { pass = pass + 1 }

	// Already-long input — copy unchanged.
	var s3 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	var r3 []byte = bytes.Center(s3, 3, 32)
	if len(r3) == 5 { pass = pass + 1 }
	if r3[0] == 1 { pass = pass + 1 }

	// Empty input — pure padding.
	var empty []byte = new(0) []byte {}
	var r4 []byte = bytes.Center(empty, 4, 42)         // '*'
	if len(r4) == 4 { pass = pass + 1 }
	if r4[0] == 42 { pass = pass + 1 }
	if r4[3] == 42 { pass = pass + 1 }

	// Single-byte input centered in 5 → 2 left, 2 right.
	var s5 []byte = new(1) []byte { 81 }   // 'Q'
	var r5 []byte = bytes.Center(s5, 5, 35)   // '#'
	if len(r5) == 5 { pass = pass + 1 }
	if r5[0] == 35 { pass = pass + 1 }
	if r5[1] == 35 { pass = pass + 1 }
	if r5[2] == 81 { pass = pass + 1 }
	if r5[3] == 35 { pass = pass + 1 }
	if r5[4] == 35 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
