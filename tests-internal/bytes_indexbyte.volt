package main
import "log"
import "bytes"

// Positive test: bytes.IndexByte / LastIndexByte / LastIndex.
// Parallel to the strings.* counterparts but on []byte slices.

fun main() int {
	var pass int = 0

	// IndexByte: first occurrence.
	var s1 []byte = new(5) []byte{10, 20, 30, 20, 50}
	if bytes.IndexByte(s1, 20) == 1 { pass = pass + 1 }

	// IndexByte: not present.
	var s2 []byte = new(3) []byte{1, 2, 3}
	if bytes.IndexByte(s2, 99) == -1 { pass = pass + 1 }

	// IndexByte: at index 0.
	var s3 []byte = new(3) []byte{7, 8, 9}
	if bytes.IndexByte(s3, 7) == 0 { pass = pass + 1 }

	// IndexByte: empty slice.
	var s4 []byte = new(0) []byte{}
	if bytes.IndexByte(s4, 7) == -1 { pass = pass + 1 }

	// LastIndexByte: last occurrence.
	var s5 []byte = new(5) []byte{10, 20, 30, 20, 50}
	if bytes.LastIndexByte(s5, 20) == 3 { pass = pass + 1 }

	// LastIndexByte: not present.
	var s6 []byte = new(3) []byte{1, 2, 3}
	if bytes.LastIndexByte(s6, 99) == -1 { pass = pass + 1 }

	// LastIndexByte: at last position.
	var s7 []byte = new(4) []byte{1, 2, 3, 4}
	if bytes.LastIndexByte(s7, 4) == 3 { pass = pass + 1 }

	// LastIndex: last multi-byte sep occurrence.
	// {1, 2, 3, 2, 3, 4} with sep {2, 3} — last at index 3.
	var s8 []byte = new(6) []byte{1, 2, 3, 2, 3, 4}
	var sep8 []byte = new(2) []byte{2, 3}
	if bytes.LastIndex(s8, sep8) == 3 { pass = pass + 1 }

	// LastIndex: not present.
	var s9 []byte = new(3) []byte{1, 2, 3}
	var sep9 []byte = new(2) []byte{9, 9}
	if bytes.LastIndex(s9, sep9) == -1 { pass = pass + 1 }

	// LastIndex: empty sep → len(s).
	var s10 []byte = new(3) []byte{1, 2, 3}
	var sep10 []byte = new(0) []byte{}
	if bytes.LastIndex(s10, sep10) == 3 { pass = pass + 1 }

	// LastIndex: sep longer than s → -1.
	var s11 []byte = new(2) []byte{1, 2}
	var sep11 []byte = new(3) []byte{1, 2, 3}
	if bytes.LastIndex(s11, sep11) == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
