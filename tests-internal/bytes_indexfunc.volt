package main
import "log"
import "bytes"

// Positive test: bytes.IndexFunc / LastIndexFunc / TrimFunc —
// predicate-based byte-slice scans parallel to strings.*.

fun isDigit(b byte) bool {
	if b >= 48 {
		if b <= 57 { ret true }
	}
	ret false
}

fun isWs(b byte) bool {
	if b == 32 { ret true }
	if b == 9 { ret true }
	if b == 10 { ret true }
	ret false
}

fun main() int {
	var pass int = 0

	// IndexFunc: first digit. {97, 98, 99, 51, 50, 49} = "abc321"
	var s1 []byte = new(6) []byte{97, 98, 99, 51, 50, 49}
	if bytes.IndexFunc(s1, isDigit) == 3 { pass = pass + 1 }

	// IndexFunc: no match.
	var s2 []byte = new(3) []byte{97, 98, 99}
	if bytes.IndexFunc(s2, isDigit) == -1 { pass = pass + 1 }

	// IndexFunc: match at index 0.
	var s3 []byte = new(3) []byte{53, 97, 98}
	if bytes.IndexFunc(s3, isDigit) == 0 { pass = pass + 1 }

	// IndexFunc: empty.
	var s4 []byte = new(0) []byte{}
	if bytes.IndexFunc(s4, isDigit) == -1 { pass = pass + 1 }

	// LastIndexFunc: last digit. "abc321x" = {97, 98, 99, 51, 50, 49, 120}
	var s5 []byte = new(7) []byte{97, 98, 99, 51, 50, 49, 120}
	if bytes.LastIndexFunc(s5, isDigit) == 5 { pass = pass + 1 }

	// LastIndexFunc: no match.
	var s6 []byte = new(3) []byte{97, 98, 99}
	if bytes.LastIndexFunc(s6, isDigit) == -1 { pass = pass + 1 }

	// TrimFunc with whitespace. "  hi  \n" → "hi"
	var s7 []byte = new(7) []byte{32, 32, 104, 105, 32, 32, 10}
	var r1 []byte = bytes.TrimFunc(s7, isWs)
	if len(r1) == 2 { pass = pass + 1 }
	if r1[0] == 104 { pass = pass + 1 }
	if r1[1] == 105 { pass = pass + 1 }

	// TrimFunc all-match → empty.
	var s8 []byte = new(3) []byte{32, 9, 10}
	var r2 []byte = bytes.TrimFunc(s8, isWs)
	if len(r2) == 0 { pass = pass + 1 }

	// TrimFunc no leading/trailing match → unchanged.
	var s9 []byte = new(3) []byte{97, 98, 99}
	var r3 []byte = bytes.TrimFunc(s9, isWs)
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == 97 { pass = pass + 1 }

	// TrimFunc strip digits from both ends.
	// "123abc456" = {49, 50, 51, 97, 98, 99, 52, 53, 54}
	var s10 []byte = new(9) []byte{49, 50, 51, 97, 98, 99, 52, 53, 54}
	var r4 []byte = bytes.TrimFunc(s10, isDigit)
	if len(r4) == 3 { pass = pass + 1 }
	if r4[0] == 97 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
