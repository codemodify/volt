package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// LongestLine — "a\nbcde\nfgh" = bytes 97, 10, 98, 99, 100, 101, 10, 102, 103, 104
	var s1 []byte = new(10) []byte { 97, 10, 98, 99, 100, 101, 10, 102, 103, 104 }
	if bytes.LongestLine(s1) == 4 { pass = pass + 1 }
	if bytes.ShortestLine(s1) == 1 { pass = pass + 1 }

	// Single line.
	var s2 []byte = new(5) []byte { 1, 2, 3, 4, 5 }
	if bytes.LongestLine(s2) == 5 { pass = pass + 1 }
	if bytes.ShortestLine(s2) == 5 { pass = pass + 1 }

	// Empty.
	var s3 []byte = new(0) []byte {}
	if bytes.LongestLine(s3) == 0 { pass = pass + 1 }
	if bytes.ShortestLine(s3) == 0 { pass = pass + 1 }

	// Trailing newline.
	var s4 []byte = new(4) []byte { 97, 98, 99, 10 }   // "abc\n"
	if bytes.LongestLine(s4) == 3 { pass = pass + 1 }
	if bytes.ShortestLine(s4) == 0 { pass = pass + 1 }

	// Multiple equal lines.
	var s5 []byte = new(11) []byte { 97, 98, 99, 10, 100, 101, 102, 10, 103, 104, 105 }   // "abc\ndef\nghi"
	if bytes.LongestLine(s5) == 3 { pass = pass + 1 }
	if bytes.ShortestLine(s5) == 3 { pass = pass + 1 }

	// All newlines.
	var s6 []byte = new(3) []byte { 10, 10, 10 }
	if bytes.LongestLine(s6) == 0 { pass = pass + 1 }
	if bytes.ShortestLine(s6) == 0 { pass = pass + 1 }

	// Last line longest.
	var s7 []byte = new(10) []byte { 97, 10, 98, 99, 10, 100, 101, 102, 103, 104 }   // "a\nbc\ndefgh"
	if bytes.LongestLine(s7) == 5 { pass = pass + 1 }
	if bytes.ShortestLine(s7) == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
