package main
import "log"
import "bytes"

// Positive test: bytes.Frequencies + bytes.MostCommonByte.

fun main() int {
	var pass int = 0

	// Frequencies — empty.
	var f0 []int = bytes.Frequencies(new(0) []byte {})
	if len(f0) == 256 { pass = pass + 1 }
	if f0[0] == 0 { pass = pass + 1 }

	// Frequencies — single byte.
	var f1 []int = bytes.Frequencies(new(1) []byte { 65 })
	if f1[65] == 1 { pass = pass + 1 }
	if f1[64] == 0 { pass = pass + 1 }

	// Frequencies — mixed payload.
	var f2 []int = bytes.Frequencies(new(5) []byte { 104, 101, 108, 108, 111 })   // "hello"
	if f2[104] == 1 { pass = pass + 1 }
	if f2[108] == 2 { pass = pass + 1 }
	if f2[111] == 1 { pass = pass + 1 }

	// Frequencies — high-bit bytes.
	var f3 []int = bytes.Frequencies(new(4) []byte { 255, 255, 255, 254 })
	if f3[255] == 3 { pass = pass + 1 }
	if f3[254] == 1 { pass = pass + 1 }

	// Frequencies — all-zero bytes accumulate at bucket 0.
	var f4 []int = bytes.Frequencies(new(5) []byte { 0, 0, 0, 0, 0 })
	if f4[0] == 5 { pass = pass + 1 }

	// MostCommonByte — clear majority.
	if bytes.MostCommonByte(new(5) []byte { 104, 101, 108, 108, 111 }) == 108 { pass = pass + 1 }

	// MostCommonByte — single.
	if bytes.MostCommonByte(new(1) []byte { 42 }) == 42 { pass = pass + 1 }

	// MostCommonByte — tie resolves to smallest.
	if bytes.MostCommonByte(new(2) []byte { 5, 10 }) == 5 { pass = pass + 1 }

	// MostCommonByte — empty returns 0.
	if bytes.MostCommonByte(new(0) []byte {}) == 0 { pass = pass + 1 }

	// MostCommonByte — high-bit byte wins.
	if bytes.MostCommonByte(new(3) []byte { 255, 255, 255 }) == 255 { pass = pass + 1 }

	// Total of Frequencies equals len.
	var sample []byte = new(7) []byte { 1, 2, 3, 1, 2, 1, 3 }
	var freq []int = bytes.Frequencies(sample)
	var total int = 0
	for i := 0; i < 256; i++ { total = total + freq[i] }
	if total == 7 { pass = pass + 1 }

	// Bucket counts match expected for sample.
	if freq[1] == 3 { pass = pass + 1 }
	if freq[2] == 2 { pass = pass + 1 }
	if freq[3] == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
