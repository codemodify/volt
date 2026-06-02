package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	var ell []byte = new(3) []byte { 46, 46, 46 }   // "..."

	// Truncate — basic.
	var t1 []byte = bytes.Truncate(new(10) []byte { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, 6, ell)
	if len(t1) == 6 { pass = pass + 1 }
	if t1[0] == 1 { pass = pass + 1 }
	if t1[2] == 3 { pass = pass + 1 }
	if t1[3] == 46 { pass = pass + 1 }   // start of ellipsis
	if t1[5] == 46 { pass = pass + 1 }

	// Truncate — passes through when short.
	var t2 []byte = bytes.Truncate(new(3) []byte { 1, 2, 3 }, 10, ell)
	if len(t2) == 3 { pass = pass + 1 }
	if t2[2] == 3 { pass = pass + 1 }

	// Truncate — exact fit.
	var t3 []byte = bytes.Truncate(new(5) []byte { 1, 2, 3, 4, 5 }, 5, ell)
	if len(t3) == 5 { pass = pass + 1 }

	// Truncate — maxBytes <= 0.
	var t4 []byte = bytes.Truncate(new(5) []byte { 1, 2, 3, 4, 5 }, 0, ell)
	if len(t4) == 0 { pass = pass + 1 }

	// Truncate — ellipsis larger than maxBytes.
	var t5 []byte = bytes.Truncate(new(10) []byte { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, 2, ell)
	if len(t5) == 2 { pass = pass + 1 }
	if t5[0] == 46 { pass = pass + 1 }

	// AbbreviateLeft — basic.
	var a1 []byte = bytes.AbbreviateLeft(new(10) []byte { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, 6, ell)
	if len(a1) == 6 { pass = pass + 1 }
	if a1[0] == 46 { pass = pass + 1 }
	if a1[2] == 46 { pass = pass + 1 }
	if a1[3] == 8 { pass = pass + 1 }
	if a1[5] == 10 { pass = pass + 1 }

	// AbbreviateLeft — passes through.
	var a2 []byte = bytes.AbbreviateLeft(new(3) []byte { 1, 2, 3 }, 10, ell)
	if len(a2) == 3 { pass = pass + 1 }

	// AbbreviateLeft — maxBytes <= 0.
	var a3 []byte = bytes.AbbreviateLeft(new(5) []byte { 1, 2, 3, 4, 5 }, 0, ell)
	if len(a3) == 0 { pass = pass + 1 }

	// AbbreviateLeft — ellipsis larger than maxBytes — returns tail of ellipsis.
	var a4 []byte = bytes.AbbreviateLeft(new(10) []byte { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }, 2, ell)
	if len(a4) == 2 { pass = pass + 1 }
	if a4[0] == 46 { pass = pass + 1 }
	if a4[1] == 46 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
