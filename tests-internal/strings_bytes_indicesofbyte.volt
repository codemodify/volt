package main
import "log"
import "strings"
import "bytes"

// Positive test: strings.IndicesOfByte + bytes.IndicesOfByte.

fun main() int {
	var pass int = 0

	// strings.IndicesOfByte — newline positions.
	var p1 []int = strings.IndicesOfByte("line1\nline2\nline3\n", 10)   // '\n'
	if len(p1) == 3 { pass = pass + 1 }
	if p1[0] == 5 { pass = pass + 1 }
	if p1[1] == 11 { pass = pass + 1 }
	if p1[2] == 17 { pass = pass + 1 }

	// strings.IndicesOfByte — single match.
	var p2 []int = strings.IndicesOfByte("hello", 101)   // 'e'
	if len(p2) == 1 { pass = pass + 1 }
	if p2[0] == 1 { pass = pass + 1 }

	// strings.IndicesOfByte — repeated.
	var p3 []int = strings.IndicesOfByte("aaaa", 97)   // 'a'
	if len(p3) == 4 { pass = pass + 1 }

	// strings.IndicesOfByte — no match.
	var p4 []int = strings.IndicesOfByte("hello", 122)   // 'z'
	if len(p4) == 0 { pass = pass + 1 }

	// strings.IndicesOfByte — empty.
	var p5 []int = strings.IndicesOfByte("", 65)
	if len(p5) == 0 { pass = pass + 1 }

	// strings.IndicesOfByte — high-bit byte.
	var p6 []int = strings.IndicesOfByte("\xffabc\xff", 255)
	if len(p6) == 2 { pass = pass + 1 }
	if p6[0] == 0 { pass = pass + 1 }
	if p6[1] == 4 { pass = pass + 1 }

	// bytes.IndicesOfByte — basic.
	var b1 []int = bytes.IndicesOfByte(new(5) []byte { 1, 2, 1, 3, 1 }, 1)
	if len(b1) == 3 { pass = pass + 1 }
	if b1[0] == 0 { pass = pass + 1 }
	if b1[2] == 4 { pass = pass + 1 }

	// bytes.IndicesOfByte — no match.
	var b2 []int = bytes.IndicesOfByte(new(3) []byte { 1, 2, 3 }, 99)
	if len(b2) == 0 { pass = pass + 1 }

	// bytes.IndicesOfByte — empty.
	var b3 []int = bytes.IndicesOfByte(new(0) []byte {}, 1)
	if len(b3) == 0 { pass = pass + 1 }

	// strings.IndicesOfByte cardinality cross-check.
	if len(strings.IndicesOfByte("hello", 108)) == strings.CountByte("hello", 108) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
