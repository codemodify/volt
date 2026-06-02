package main
import "log"
import "bytes"
import "strings"

// Positive test: bytes.Compare / bytes.EqualFold / strings.Compare.
// Three-way comparison (-1, 0, +1) and case-insensitive equality.

fun main() int {
	var pass int = 0

	// bytes.Compare: equal.
	var a1 []byte = new(3) []byte{1, 2, 3}
	var b1 []byte = new(3) []byte{1, 2, 3}
	if bytes.Compare(a1, b1) == 0 { pass = pass + 1 }

	// bytes.Compare: a < b (first differing byte smaller).
	var a2 []byte = new(3) []byte{1, 2, 3}
	var b2 []byte = new(3) []byte{1, 3, 0}
	if bytes.Compare(a2, b2) == -1 { pass = pass + 1 }

	// bytes.Compare: a > b.
	var a3 []byte = new(3) []byte{1, 9, 0}
	var b3 []byte = new(3) []byte{1, 2, 3}
	if bytes.Compare(a3, b3) == 1 { pass = pass + 1 }

	// bytes.Compare: length tiebreak (a shorter → a < b).
	var a4 []byte = new(2) []byte{1, 2}
	var b4 []byte = new(3) []byte{1, 2, 0}
	if bytes.Compare(a4, b4) == -1 { pass = pass + 1 }

	// bytes.Compare: length tiebreak (a longer → a > b).
	var a5 []byte = new(3) []byte{1, 2, 0}
	var b5 []byte = new(2) []byte{1, 2}
	if bytes.Compare(a5, b5) == 1 { pass = pass + 1 }

	// bytes.Compare: both empty.
	var a6 []byte = new(0) []byte{}
	var b6 []byte = new(0) []byte{}
	if bytes.Compare(a6, b6) == 0 { pass = pass + 1 }

	// bytes.EqualFold: ASCII case-insensitive match.
	var a7 []byte = new(3) []byte{72, 73, 33}    // "HI!"
	var b7 []byte = new(3) []byte{104, 105, 33}  // "hi!"
	if bytes.EqualFold(a7, b7) { pass = pass + 1 }

	// bytes.EqualFold: different.
	var a8 []byte = new(3) []byte{72, 73, 33}
	var b8 []byte = new(3) []byte{104, 89, 33}   // "hY!"
	if !bytes.EqualFold(a8, b8) { pass = pass + 1 }

	// bytes.EqualFold: different lengths.
	var a9 []byte = new(2) []byte{72, 73}
	var b9 []byte = new(3) []byte{104, 105, 33}
	if !bytes.EqualFold(a9, b9) { pass = pass + 1 }

	// strings.Compare.
	if strings.Compare("apple", "apple") == 0 { pass = pass + 1 }
	if strings.Compare("apple", "banana") == -1 { pass = pass + 1 }
	if strings.Compare("banana", "apple") == 1 { pass = pass + 1 }
	if strings.Compare("ab", "abc") == -1 { pass = pass + 1 }
	if strings.Compare("abc", "ab") == 1 { pass = pass + 1 }
	if strings.Compare("", "") == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
