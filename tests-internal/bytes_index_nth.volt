package main
import "log"
import "bytes"

fun strBytes(s string) []byte {
	var n int = len(s)
	var out []byte = new(n) []byte {}
	for i := 0; i < n; i++ { out[i] = s[i] }
	ret out
}

fun main() int {
	var pass int = 0

	// Empty.
	var e []byte = new(0) []byte {}
	if bytes.IndexNthByte(e, 65, 0) == -1 { pass = pass + 1 }
	var e2 []byte = new(0) []byte {}
	var sub0 []byte = new(1) []byte { 65 }
	if bytes.IndexNth(e2, sub0, 0) == -1 { pass = pass + 1 }

	// No occurrence.
	var s1 []byte = strBytes("abc")
	if bytes.IndexNthByte(s1, 88, 0) == -1 { pass = pass + 1 }

	// IndexNthByte: comma positions.
	var csv []byte = strBytes("a,b,c,d,e")
	if bytes.IndexNthByte(csv, 44, 0) == 1 { pass = pass + 1 }
	var csv2 []byte = strBytes("a,b,c,d,e")
	if bytes.IndexNthByte(csv2, 44, 1) == 3 { pass = pass + 1 }
	var csv3 []byte = strBytes("a,b,c,d,e")
	if bytes.IndexNthByte(csv3, 44, 2) == 5 { pass = pass + 1 }
	var csv4 []byte = strBytes("a,b,c,d,e")
	if bytes.IndexNthByte(csv4, 44, 3) == 7 { pass = pass + 1 }
	var csv5 []byte = strBytes("a,b,c,d,e")
	if bytes.IndexNthByte(csv5, 44, 4) == -1 { pass = pass + 1 }

	// IndexNth substring.
	var s2 []byte = strBytes("foobarfoobazfoo")
	var sub []byte = strBytes("foo")
	if bytes.IndexNth(s2, sub, 0) == 0 { pass = pass + 1 }
	var s2b []byte = strBytes("foobarfoobazfoo")
	var sub2 []byte = strBytes("foo")
	if bytes.IndexNth(s2b, sub2, 1) == 6 { pass = pass + 1 }
	var s2c []byte = strBytes("foobarfoobazfoo")
	var sub3 []byte = strBytes("foo")
	if bytes.IndexNth(s2c, sub3, 2) == 12 { pass = pass + 1 }
	var s2d []byte = strBytes("foobarfoobazfoo")
	var sub4 []byte = strBytes("foo")
	if bytes.IndexNth(s2d, sub4, 3) == -1 { pass = pass + 1 }

	// Non-overlapping advance.
	var s3 []byte = strBytes("aaaa")
	var aa1 []byte = strBytes("aa")
	if bytes.IndexNth(s3, aa1, 0) == 0 { pass = pass + 1 }
	var s3b []byte = strBytes("aaaa")
	var aa2 []byte = strBytes("aa")
	if bytes.IndexNth(s3b, aa2, 1) == 2 { pass = pass + 1 }
	var s3c []byte = strBytes("aaaa")
	var aa3 []byte = strBytes("aa")
	if bytes.IndexNth(s3c, aa3, 2) == -1 { pass = pass + 1 }

	// Empty sub returns -1.
	var s4 []byte = strBytes("hello")
	var empty []byte = new(0) []byte {}
	if bytes.IndexNth(s4, empty, 0) == -1 { pass = pass + 1 }

	// n < 0.
	var s5 []byte = strBytes("hello")
	if bytes.IndexNthByte(s5, 108, -1) == -1 { pass = pass + 1 }

	// High-bit bytes survive.
	var s6 []byte = new(5) []byte { 200, 50, 200, 50, 200 }
	if bytes.IndexNthByte(s6, 200, 1) == 2 { pass = pass + 1 }
	var s6b []byte = new(5) []byte { 200, 50, 200, 50, 200 }
	if bytes.IndexNthByte(s6b, 200, 2) == 4 { pass = pass + 1 }

	// Tab use case.
	var rec []byte = strBytes("col1\tcol2\tcol3\tcol4")
	if bytes.IndexNthByte(rec, 9, 1) == 9 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
