package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// CommonPrefix — basic.
	var p1 []byte = bytes.CommonPrefix(new(4) []byte { 1, 2, 3, 4 }, new(4) []byte { 1, 2, 9, 8 })
	if len(p1) == 2 { pass = pass + 1 }
	if p1[0] == 1 { pass = pass + 1 }
	if p1[1] == 2 { pass = pass + 1 }

	// CommonPrefix — full match.
	var p2 []byte = bytes.CommonPrefix(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 2, 3 })
	if len(p2) == 3 { pass = pass + 1 }
	if p2[2] == 3 { pass = pass + 1 }

	// CommonPrefix — first byte differs.
	var p3 []byte = bytes.CommonPrefix(new(3) []byte { 1, 2, 3 }, new(3) []byte { 9, 8, 7 })
	if len(p3) == 0 { pass = pass + 1 }

	// CommonPrefix — empty operand.
	var p4 []byte = bytes.CommonPrefix(new(0) []byte {}, new(3) []byte { 1, 2, 3 })
	if len(p4) == 0 { pass = pass + 1 }
	var p5 []byte = bytes.CommonPrefix(new(0) []byte {}, new(0) []byte {})
	if len(p5) == 0 { pass = pass + 1 }

	// CommonPrefix — prefix-of.
	var p6 []byte = bytes.CommonPrefix(new(2) []byte { 1, 2 }, new(5) []byte { 1, 2, 3, 4, 5 })
	if len(p6) == 2 { pass = pass + 1 }
	if p6[1] == 2 { pass = pass + 1 }

	// CommonSuffix — basic.
	var s1 []byte = bytes.CommonSuffix(new(5) []byte { 1, 2, 3, 4, 5 }, new(5) []byte { 9, 8, 3, 4, 5 })
	if len(s1) == 3 { pass = pass + 1 }
	if s1[0] == 3 { pass = pass + 1 }
	if s1[2] == 5 { pass = pass + 1 }

	// CommonSuffix — full match.
	var s2 []byte = bytes.CommonSuffix(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 2, 3 })
	if len(s2) == 3 { pass = pass + 1 }

	// CommonSuffix — last byte differs.
	var s3 []byte = bytes.CommonSuffix(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 2, 9 })
	if len(s3) == 0 { pass = pass + 1 }

	// CommonSuffix — empty.
	var s4 []byte = bytes.CommonSuffix(new(0) []byte {}, new(3) []byte { 1, 2, 3 })
	if len(s4) == 0 { pass = pass + 1 }

	// CommonSuffix — suffix-of.
	var s5 []byte = bytes.CommonSuffix(new(2) []byte { 4, 5 }, new(5) []byte { 1, 2, 3, 4, 5 })
	if len(s5) == 2 { pass = pass + 1 }
	if s5[0] == 4 { pass = pass + 1 }
	if s5[1] == 5 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
