package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// "hello" = 104, 101, 108, 108, 111
	var hello []byte = new(5) []byte { 104, 101, 108, 108, 111 }

	// from=0 finds first 'l' (108).
	if bytes.IndexByteAfter(hello, 108, 0) == 2 { pass = pass + 1 }

	// from=3 finds second 'l' (108).
	if bytes.IndexByteAfter(hello, 108, 3) == 3 { pass = pass + 1 }

	// from=4 → no more 'l'.
	if bytes.IndexByteAfter(hello, 108, 4) == -1 { pass = pass + 1 }

	// 'o' at index 4.
	if bytes.IndexByteAfter(hello, 111, 0) == 4 { pass = pass + 1 }

	// Iteration over "a,b,c,d" finding commas.
	var s []byte = new(7) []byte { 97, 44, 98, 44, 99, 44, 100 }
	var i1 int = bytes.IndexByteAfter(s, 44, 0)
	var i2 int = bytes.IndexByteAfter(s, 44, i1 + 1)
	var i3 int = bytes.IndexByteAfter(s, 44, i2 + 1)
	var i4 int = bytes.IndexByteAfter(s, 44, i3 + 1)
	if i1 == 1 { pass = pass + 1 }
	if i2 == 3 { pass = pass + 1 }
	if i3 == 5 { pass = pass + 1 }
	if i4 == -1 { pass = pass + 1 }

	// Negative from clamps to 0.
	if bytes.IndexByteAfter(hello, 104, -3) == 0 { pass = pass + 1 }

	// from past end → -1.
	if bytes.IndexByteAfter(hello, 104, 100) == -1 { pass = pass + 1 }
	if bytes.IndexByteAfter(hello, 104, 5) == -1 { pass = pass + 1 }

	// Empty slice.
	var empty []byte = new(0) []byte {}
	if bytes.IndexByteAfter(empty, 97, 0) == -1 { pass = pass + 1 }

	// Match at exact from-boundary.
	if bytes.IndexByteAfter(hello, 108, 2) == 2 { pass = pass + 1 }

	// Byte not present.
	if bytes.IndexByteAfter(hello, 122, 0) == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
