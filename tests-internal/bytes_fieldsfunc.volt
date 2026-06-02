package main
import "log"
import "bytes"

fun isComma(b byte) bool { ret b == 44 }
fun isCommaOrSemi(b byte) bool {
	if b == 44 { ret true }
	if b == 59 { ret true }
	ret false
}
fun isDigit(b byte) bool {
	if b < 48 { ret false }
	if b > 57 { ret false }
	ret true
}
fun isAllTrue(b byte) bool { ret true }

fun main() int {
	var pass int = 0

	// "a,b,c"
	var s1 []byte = new(5) []byte { 97, 44, 98, 44, 99 }
	var p1 [][]byte = bytes.FieldsFunc(s1, isComma)
	if len(p1) == 3 { pass = pass + 1 }
	if len(p1[0]) == 1 { pass = pass + 1 }
	if p1[0][0] == 97 { pass = pass + 1 }
	if p1[2][0] == 99 { pass = pass + 1 }

	// "a,b;c,d;e" — multi-set separators.
	var s2 []byte = new(9) []byte { 97, 44, 98, 59, 99, 44, 100, 59, 101 }
	var p2 [][]byte = bytes.FieldsFunc(s2, isCommaOrSemi)
	if len(p2) == 5 { pass = pass + 1 }
	if p2[0][0] == 97 { pass = pass + 1 }
	if p2[4][0] == 101 { pass = pass + 1 }

	// "a,,,b,,c" — runs collapse.
	var s3 []byte = new(8) []byte { 97, 44, 44, 44, 98, 44, 44, 99 }
	var p3 [][]byte = bytes.FieldsFunc(s3, isComma)
	if len(p3) == 3 { pass = pass + 1 }
	if p3[0][0] == 97 { pass = pass + 1 }
	if p3[1][0] == 98 { pass = pass + 1 }
	if p3[2][0] == 99 { pass = pass + 1 }

	// ",,a,b,," — leading + trailing trimmed.
	var s4 []byte = new(7) []byte { 44, 44, 97, 44, 98, 44, 44 }
	var p4 [][]byte = bytes.FieldsFunc(s4, isComma)
	if len(p4) == 2 { pass = pass + 1 }
	if p4[0][0] == 97 { pass = pass + 1 }

	// Empty input.
	var empty []byte = new(0) []byte {}
	var p5 [][]byte = bytes.FieldsFunc(empty, isComma)
	if len(p5) == 0 { pass = pass + 1 }

	// All separators → no fields.
	var s6 []byte = new(3) []byte { 44, 44, 44 }
	var p6 [][]byte = bytes.FieldsFunc(s6, isComma)
	if len(p6) == 0 { pass = pass + 1 }

	// Digit-boundary split: "aa1bb22cc3".
	var s7 []byte = new(10) []byte { 97, 97, 49, 98, 98, 50, 50, 99, 99, 51 }
	var p7 [][]byte = bytes.FieldsFunc(s7, isDigit)
	if len(p7) == 3 { pass = pass + 1 }
	if len(p7[0]) == 2 { pass = pass + 1 }   // "aa"
	if p7[0][0] == 97 { pass = pass + 1 }
	if len(p7[2]) == 2 { pass = pass + 1 }   // "cc"

	// All-true predicate → empty result.
	var s8 []byte = new(3) []byte { 120, 121, 122 }
	var p8 [][]byte = bytes.FieldsFunc(s8, isAllTrue)
	if len(p8) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
