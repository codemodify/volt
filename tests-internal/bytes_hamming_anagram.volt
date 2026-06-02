package main
import "log"
import "bytes"

// Positive test: bytes.HammingDistance + bytes.IsAnagram.

fun main() int {
	var pass int = 0

	// HammingDistance — identical.
	if bytes.HammingDistance(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 2, 3 }) == 0 { pass = pass + 1 }

	// HammingDistance — single difference.
	if bytes.HammingDistance(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 9, 3 }) == 1 { pass = pass + 1 }

	// HammingDistance — all different.
	if bytes.HammingDistance(new(3) []byte { 1, 2, 3 }, new(3) []byte { 4, 5, 6 }) == 3 { pass = pass + 1 }

	// HammingDistance — both empty.
	if bytes.HammingDistance(new(0) []byte {}, new(0) []byte {}) == 0 { pass = pass + 1 }

	// HammingDistance — length mismatch → -1.
	if bytes.HammingDistance(new(2) []byte { 1, 2 }, new(3) []byte { 1, 2, 3 }) == -1 { pass = pass + 1 }
	if bytes.HammingDistance(new(0) []byte {}, new(1) []byte { 0 }) == -1 { pass = pass + 1 }

	// HammingDistance — high-bit bytes (0xff vs 0xfe etc.).
	if bytes.HammingDistance(new(4) []byte { 255, 255, 255, 255 }, new(4) []byte { 254, 255, 254, 255 }) == 2 { pass = pass + 1 }

	// IsAnagram — true cases.
	if bytes.IsAnagram(new(3) []byte { 1, 2, 3 }, new(3) []byte { 3, 2, 1 }) { pass = pass + 1 }
	if bytes.IsAnagram(new(5) []byte { 65, 65, 66, 66, 67 }, new(5) []byte { 67, 66, 65, 66, 65 }) { pass = pass + 1 }

	// IsAnagram — identical is trivially anagram.
	if bytes.IsAnagram(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 2, 3 }) { pass = pass + 1 }

	// IsAnagram — both empty.
	if bytes.IsAnagram(new(0) []byte {}, new(0) []byte {}) { pass = pass + 1 }

	// IsAnagram — length mismatch → false.
	if !bytes.IsAnagram(new(2) []byte { 1, 2 }, new(3) []byte { 1, 2, 1 }) { pass = pass + 1 }

	// IsAnagram — same length, different histogram → false.
	if !bytes.IsAnagram(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 2, 4 }) { pass = pass + 1 }

	// IsAnagram — duplicate-byte-count matters.
	if !bytes.IsAnagram(new(4) []byte { 1, 1, 2, 2 }, new(4) []byte { 1, 1, 1, 2 }) { pass = pass + 1 }

	// IsAnagram — high-bit bytes.
	if bytes.IsAnagram(new(3) []byte { 200, 100, 50 }, new(3) []byte { 50, 100, 200 }) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
