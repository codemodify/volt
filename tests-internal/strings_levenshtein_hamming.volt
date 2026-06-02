package main
import "log"
import "strings"

// Positive test: strings.Levenshtein + strings.HammingDistance.

fun main() int {
	var pass int = 0

	// Hamming — equal-length pairs.
	if strings.HammingDistance("karolin", "kathrin") == 3 { pass = pass + 1 }
	if strings.HammingDistance("karolin", "kerstin") == 3 { pass = pass + 1 }
	if strings.HammingDistance("1011101", "1001001") == 2 { pass = pass + 1 }
	if strings.HammingDistance("2173896", "2233796") == 3 { pass = pass + 1 }

	// Hamming — identical.
	if strings.HammingDistance("same", "same") == 0 { pass = pass + 1 }
	if strings.HammingDistance("", "") == 0 { pass = pass + 1 }

	// Hamming — different lengths returns -1.
	if strings.HammingDistance("short", "longer") == -1 { pass = pass + 1 }
	if strings.HammingDistance("", "x") == -1 { pass = pass + 1 }

	// Hamming — all-different.
	if strings.HammingDistance("abc", "xyz") == 3 { pass = pass + 1 }

	// Levenshtein — classic examples.
	if strings.Levenshtein("kitten", "sitting") == 3 { pass = pass + 1 }
	if strings.Levenshtein("Saturday", "Sunday") == 3 { pass = pass + 1 }
	if strings.Levenshtein("flaw", "lawn") == 2 { pass = pass + 1 }

	// Levenshtein — identical.
	if strings.Levenshtein("same", "same") == 0 { pass = pass + 1 }
	if strings.Levenshtein("", "") == 0 { pass = pass + 1 }

	// Levenshtein — one empty (distance = other length).
	if strings.Levenshtein("", "abc") == 3 { pass = pass + 1 }
	if strings.Levenshtein("abc", "") == 3 { pass = pass + 1 }

	// Levenshtein — single edit.
	if strings.Levenshtein("cat", "bat") == 1 { pass = pass + 1 }   // sub
	if strings.Levenshtein("cat", "cats") == 1 { pass = pass + 1 }  // insert
	if strings.Levenshtein("cats", "cat") == 1 { pass = pass + 1 }  // delete

	// Levenshtein — all-different.
	if strings.Levenshtein("abc", "xyz") == 3 { pass = pass + 1 }

	// Levenshtein — single chars.
	if strings.Levenshtein("a", "b") == 1 { pass = pass + 1 }
	if strings.Levenshtein("a", "a") == 0 { pass = pass + 1 }

	// Symmetry: Levenshtein(a,b) == Levenshtein(b,a).
	if strings.Levenshtein("kitten", "sitting") == strings.Levenshtein("sitting", "kitten") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
