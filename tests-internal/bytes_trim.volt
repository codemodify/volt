package main
import "log"
import "bytes"

// Positive test: bytes.TrimSpace / TrimPrefix / TrimSuffix.

fun main() int {
	var pass int = 0

	// TrimSpace: strip leading + trailing whitespace.
	// "  hi  " → "hi" (bytes 32,32,104,105,32,32)
	var s1 []byte = new(6) []byte{32, 32, 104, 105, 32, 32}
	var t1 []byte = bytes.TrimSpace(s1)
	if len(t1) == 2 { pass = pass + 1 }
	if t1[0] == 104 { pass = pass + 1 }
	if t1[1] == 105 { pass = pass + 1 }

	// TrimSpace: all whitespace → empty.
	var s2 []byte = new(4) []byte{32, 9, 10, 13}
	var t2 []byte = bytes.TrimSpace(s2)
	if len(t2) == 0 { pass = pass + 1 }

	// TrimSpace: no leading/trailing whitespace → unchanged.
	var s3 []byte = new(3) []byte{1, 2, 3}
	var t3 []byte = bytes.TrimSpace(s3)
	if len(t3) == 3 { pass = pass + 1 }
	if t3[0] == 1 { pass = pass + 1 }
	if t3[2] == 3 { pass = pass + 1 }

	// TrimPrefix: present.
	var s4 []byte = new(5) []byte{65, 66, 67, 68, 69}    // ABCDE
	var p4 []byte = new(2) []byte{65, 66}                 // AB
	var t4 []byte = bytes.TrimPrefix(s4, p4)
	if len(t4) == 3 { pass = pass + 1 }
	if t4[0] == 67 { pass = pass + 1 }

	// TrimPrefix: absent → unchanged copy.
	var s5 []byte = new(3) []byte{65, 66, 67}
	var p5 []byte = new(2) []byte{99, 100}
	var t5 []byte = bytes.TrimPrefix(s5, p5)
	if len(t5) == 3 { pass = pass + 1 }
	if t5[0] == 65 { pass = pass + 1 }

	// TrimSuffix: present.
	var s6 []byte = new(5) []byte{65, 66, 67, 68, 69}
	var x6 []byte = new(2) []byte{68, 69}                 // DE
	var t6 []byte = bytes.TrimSuffix(s6, x6)
	if len(t6) == 3 { pass = pass + 1 }
	if t6[2] == 67 { pass = pass + 1 }

	// TrimSuffix: absent → unchanged copy.
	var s7 []byte = new(3) []byte{65, 66, 67}
	var x7 []byte = new(2) []byte{99, 100}
	var t7 []byte = bytes.TrimSuffix(s7, x7)
	if len(t7) == 3 { pass = pass + 1 }
	if t7[2] == 67 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
