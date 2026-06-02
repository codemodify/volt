package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	var ell []byte = new(3) []byte { 46, 46, 46 }   // "..."

	// AbbreviateMiddle — basic.
	var a1 []byte = bytes.AbbreviateMiddle(new(10) []byte { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, 8, ell)
	if len(a1) == 8 { pass = pass + 1 }
	if a1[0] == 1 { pass = pass + 1 }
	if a1[2] == 3 { pass = pass + 1 }
	if a1[3] == 46 { pass = pass + 1 }
	if a1[5] == 46 { pass = pass + 1 }
	if a1[6] == 9 { pass = pass + 1 }
	if a1[7] == 10 { pass = pass + 1 }

	// AbbreviateMiddle — passes through when short.
	var a2 []byte = bytes.AbbreviateMiddle(new(3) []byte { 1, 2, 3 }, 10, ell)
	if len(a2) == 3 { pass = pass + 1 }

	// AbbreviateMiddle — maxBytes <= 0 returns empty.
	var a3 []byte = bytes.AbbreviateMiddle(new(5) []byte { 1, 2, 3, 4, 5 }, 0, ell)
	if len(a3) == 0 { pass = pass + 1 }

	// AbbreviateMiddle — ellipsis larger than maxBytes (head fallback).
	var a4 []byte = bytes.AbbreviateMiddle(new(10) []byte { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, 2, ell)
	if len(a4) == 2 { pass = pass + 1 }
	if a4[0] == 1 { pass = pass + 1 }
	if a4[1] == 2 { pass = pass + 1 }

	// AbbreviateMiddle — empty ellipsis (just concat prefix + suffix).
	var emptyEll []byte = new(0) []byte {}
	var a5 []byte = bytes.AbbreviateMiddle(new(6) []byte { 1, 2, 3, 4, 5, 6 }, 4, emptyEll)
	if len(a5) == 4 { pass = pass + 1 }
	if a5[0] == 1 { pass = pass + 1 }
	if a5[1] == 2 { pass = pass + 1 }
	if a5[2] == 5 { pass = pass + 1 }
	if a5[3] == 6 { pass = pass + 1 }

	// AbbreviateMiddle — single-byte ellipsis.
	var dot []byte = new(1) []byte { 42 }
	var a6 []byte = bytes.AbbreviateMiddle(new(8) []byte { 1, 2, 3, 4, 5, 6, 7, 8 }, 5, dot)
	if len(a6) == 5 { pass = pass + 1 }
	if a6[0] == 1 { pass = pass + 1 }
	if a6[1] == 2 { pass = pass + 1 }
	if a6[2] == 42 { pass = pass + 1 }   // ellipsis
	if a6[3] == 7 { pass = pass + 1 }
	if a6[4] == 8 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
