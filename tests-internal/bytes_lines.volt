package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// Lines — empty input.
	var empty []byte = new(0) []byte {}
	var emptyOut [][]byte = bytes.Lines(empty)
	if len(emptyOut) == 0 { pass = pass + 1 }

	// Lines — single line, no trailing newline.
	var single []byte = new(5) []byte { 104, 101, 108, 108, 111 }   // "hello"
	var singleOut [][]byte = bytes.Lines(single)
	if len(singleOut) == 1 { pass = pass + 1 }
	if len(singleOut[0]) == 5 { pass = pass + 1 }
	if singleOut[0][0] == 104 { pass = pass + 1 }
	if singleOut[0][4] == 111 { pass = pass + 1 }

	// Lines — two LF-separated lines.
	var two []byte = new(7) []byte { 97, 10, 98, 99, 10, 100, 101 }   // "a\nbc\nde"
	var twoOut [][]byte = bytes.Lines(two)
	if len(twoOut) == 3 { pass = pass + 1 }
	if len(twoOut[0]) == 1 { pass = pass + 1 }       // "a"
	if twoOut[0][0] == 97 { pass = pass + 1 }
	if len(twoOut[1]) == 2 { pass = pass + 1 }       // "bc"
	if twoOut[1][0] == 98 { pass = pass + 1 }
	if twoOut[1][1] == 99 { pass = pass + 1 }
	if len(twoOut[2]) == 2 { pass = pass + 1 }       // "de"

	// Lines — CRLF stripped.
	var crlf []byte = new(7) []byte { 97, 13, 10, 98, 13, 10, 99 }   // "a\r\nb\r\nc"
	var crlfOut [][]byte = bytes.Lines(crlf)
	if len(crlfOut) == 3 { pass = pass + 1 }
	if len(crlfOut[0]) == 1 { pass = pass + 1 }      // "a" (no \r)
	if crlfOut[0][0] == 97 { pass = pass + 1 }
	if len(crlfOut[1]) == 1 { pass = pass + 1 }      // "b" (no \r)
	if crlfOut[1][0] == 98 { pass = pass + 1 }
	if len(crlfOut[2]) == 1 { pass = pass + 1 }      // "c"

	// Lines — trailing newline does NOT add empty line.
	var trail []byte = new(2) []byte { 97, 10 }      // "a\n"
	var trailOut [][]byte = bytes.Lines(trail)
	if len(trailOut) == 1 { pass = pass + 1 }
	if len(trailOut[0]) == 1 { pass = pass + 1 }

	// Lines — empty interior line.
	var blank []byte = new(3) []byte { 10, 10, 10 }   // "\n\n\n"
	var blankOut [][]byte = bytes.Lines(blank)
	if len(blankOut) == 3 { pass = pass + 1 }
	if len(blankOut[0]) == 0 { pass = pass + 1 }
	if len(blankOut[1]) == 0 { pass = pass + 1 }
	if len(blankOut[2]) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
