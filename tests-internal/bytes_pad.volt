package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// PadLeft basic.
	var s1 []byte = new(3) []byte { 65, 66, 67 }   // "ABC"
	var r1 []byte = bytes.PadLeft(s1, 6, 32)
	if len(r1) == 6 { pass = pass + 1 }
	if r1[0] == 32 { pass = pass + 1 }    // ' '
	if r1[1] == 32 { pass = pass + 1 }
	if r1[2] == 32 { pass = pass + 1 }
	if r1[3] == 65 { pass = pass + 1 }    // 'A'
	if r1[5] == 67 { pass = pass + 1 }    // 'C'

	// PadLeft with already-long input → copy unchanged.
	var s2 []byte = new(5) []byte { 65, 66, 67, 68, 69 }
	var r2 []byte = bytes.PadLeft(s2, 3, 32)
	if len(r2) == 5 { pass = pass + 1 }
	if r2[0] == 65 { pass = pass + 1 }

	// PadLeft on empty.
	var empty []byte = new(0) []byte {}
	var r3 []byte = bytes.PadLeft(empty, 4, 48)   // pad with '0'
	if len(r3) == 4 { pass = pass + 1 }
	if r3[0] == 48 { pass = pass + 1 }
	if r3[3] == 48 { pass = pass + 1 }

	// PadRight basic.
	var s3 []byte = new(3) []byte { 88, 89, 90 }    // "XYZ"
	var r4 []byte = bytes.PadRight(s3, 7, 46)        // pad with '.'
	if len(r4) == 7 { pass = pass + 1 }
	if r4[0] == 88 { pass = pass + 1 }
	if r4[2] == 90 { pass = pass + 1 }
	if r4[3] == 46 { pass = pass + 1 }
	if r4[6] == 46 { pass = pass + 1 }

	// PadRight already-long.
	var s4 []byte = new(5) []byte { 65, 66, 67, 68, 69 }
	var r5 []byte = bytes.PadRight(s4, 3, 32)
	if len(r5) == 5 { pass = pass + 1 }

	// PadRight on empty.
	var r6 []byte = bytes.PadRight(empty, 3, 35)    // '#'
	if len(r6) == 3 { pass = pass + 1 }
	if r6[0] == 35 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
