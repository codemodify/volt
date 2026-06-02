package main
import "log"
import "bytes"

// Positive test: bytes.RemoveChars + bytes.Levenshtein.

fun main() int {
	var pass int = 0

	// RemoveChars — basic.
	var r1 []byte = bytes.RemoveChars(new(5) []byte { 1, 2, 3, 4, 5 }, new(2) []byte { 2, 4 })
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == 1 { pass = pass + 1 }
	if r1[1] == 3 { pass = pass + 1 }
	if r1[2] == 5 { pass = pass + 1 }

	// RemoveChars — empty chars returns copy.
	var r2 []byte = bytes.RemoveChars(new(3) []byte { 1, 2, 3 }, new(0) []byte {})
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 1 { pass = pass + 1 }

	// RemoveChars — empty input.
	var r3 []byte = bytes.RemoveChars(new(0) []byte {}, new(2) []byte { 1, 2 })
	if len(r3) == 0 { pass = pass + 1 }

	// RemoveChars — strip all.
	var r4 []byte = bytes.RemoveChars(new(3) []byte { 7, 7, 7 }, new(1) []byte { 7 })
	if len(r4) == 0 { pass = pass + 1 }

	// RemoveChars — no match.
	var r5 []byte = bytes.RemoveChars(new(3) []byte { 1, 2, 3 }, new(2) []byte { 99, 100 })
	if len(r5) == 3 { pass = pass + 1 }

	// Levenshtein — classic.
	if bytes.Levenshtein(new(6) []byte { 107, 105, 116, 116, 101, 110 }, new(7) []byte { 115, 105, 116, 116, 105, 110, 103 }) == 3 { pass = pass + 1 }
	// "kitten" → "sitting"

	// Levenshtein — identical.
	if bytes.Levenshtein(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 2, 3 }) == 0 { pass = pass + 1 }

	// Levenshtein — both empty.
	if bytes.Levenshtein(new(0) []byte {}, new(0) []byte {}) == 0 { pass = pass + 1 }

	// Levenshtein — one empty.
	if bytes.Levenshtein(new(0) []byte {}, new(3) []byte { 1, 2, 3 }) == 3 { pass = pass + 1 }
	if bytes.Levenshtein(new(3) []byte { 1, 2, 3 }, new(0) []byte {}) == 3 { pass = pass + 1 }

	// Levenshtein — single edit.
	if bytes.Levenshtein(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 9, 3 }) == 1 { pass = pass + 1 }    // substitute
	if bytes.Levenshtein(new(3) []byte { 1, 2, 3 }, new(4) []byte { 1, 2, 3, 4 }) == 1 { pass = pass + 1 } // insert
	if bytes.Levenshtein(new(4) []byte { 1, 2, 3, 4 }, new(3) []byte { 1, 2, 3 }) == 1 { pass = pass + 1 } // delete

	// Levenshtein — all different.
	if bytes.Levenshtein(new(3) []byte { 1, 2, 3 }, new(3) []byte { 4, 5, 6 }) == 3 { pass = pass + 1 }

	// Levenshtein — symmetry.
	if bytes.Levenshtein(new(3) []byte { 1, 2, 3 }, new(4) []byte { 1, 2, 3, 4 }) == bytes.Levenshtein(new(4) []byte { 1, 2, 3, 4 }, new(3) []byte { 1, 2, 3 }) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
