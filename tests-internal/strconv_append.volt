package main
import "log"
import "strconv"

// Positive test: strconv.AppendInt + AppendBool. Append-style API
// extending an existing []byte instead of allocating a fresh string.

fun main() int {
	var pass int = 0

	// AppendInt base 10: "n=" prefix then append 42.
	var p1 []byte = new(2) []byte{110, 61}   // "n="
	var r1 []byte = strconv.AppendInt(p1, 42, 10)
	if len(r1) == 4 { pass = pass + 1 }
	if r1[0] == 110 { pass = pass + 1 }  // 'n'
	if r1[2] == 52 { pass = pass + 1 }   // '4'
	if r1[3] == 50 { pass = pass + 1 }   // '2'

	// AppendInt base 16.
	var p2 []byte = new(2) []byte{48, 120}   // "0x"
	var r2 []byte = strconv.AppendInt(p2, 255, 16)
	if len(r2) == 4 { pass = pass + 1 }
	if r2[2] == 102 { pass = pass + 1 }  // 'f'
	if r2[3] == 102 { pass = pass + 1 }  // 'f'

	// AppendInt with negative.
	var p3 []byte = new(0) []byte{}
	var r3 []byte = strconv.AppendInt(p3, -123, 10)
	if len(r3) == 4 { pass = pass + 1 }
	if r3[0] == 45 { pass = pass + 1 }   // '-'
	if r3[1] == 49 { pass = pass + 1 }   // '1'

	// AppendBool true.
	var p4 []byte = new(1) []byte{61}       // "="
	var r4 []byte = strconv.AppendBool(p4, true)
	if len(r4) == 5 { pass = pass + 1 }
	if r4[1] == 116 { pass = pass + 1 }  // 't'
	if r4[4] == 101 { pass = pass + 1 }  // 'e'

	// AppendBool false.
	var p5 []byte = new(0) []byte{}
	var r5 []byte = strconv.AppendBool(p5, false)
	if len(r5) == 5 { pass = pass + 1 }
	if r5[0] == 102 { pass = pass + 1 }  // 'f'
	if r5[4] == 101 { pass = pass + 1 }  // 'e'

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
