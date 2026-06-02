package main
import "log"
import "bytes"

// Positive test: bytes.IsAscii + bytes.Translate.

fun main() int {
	var pass int = 0

	// IsAscii — empty.
	if bytes.IsAscii(new(0) []byte {}) { pass = pass + 1 }

	// IsAscii — pure ASCII.
	if bytes.IsAscii(new(5) []byte { 72, 101, 108, 108, 111 }) { pass = pass + 1 }   // "Hello"

	// IsAscii — boundary 127 still ASCII.
	if bytes.IsAscii(new(3) []byte { 0, 64, 127 }) { pass = pass + 1 }

	// IsAscii — 128+ fails.
	if !bytes.IsAscii(new(3) []byte { 65, 200, 66 }) { pass = pass + 1 }
	if !bytes.IsAscii(new(1) []byte { 128 }) { pass = pass + 1 }
	if !bytes.IsAscii(new(2) []byte { 255, 0 }) { pass = pass + 1 }

	// Translate — straight substitution.
	var r1 []byte = bytes.Translate(new(3) []byte { 1, 2, 3 }, new(2) []byte { 1, 2 }, new(2) []byte { 9, 8 })
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == 9 { pass = pass + 1 }
	if r1[1] == 8 { pass = pass + 1 }
	if r1[2] == 3 { pass = pass + 1 }

	// Translate — delete when from longer than to.
	var r2 []byte = bytes.Translate(new(4) []byte { 1, 2, 3, 4 }, new(2) []byte { 1, 3 }, new(1) []byte { 9 })
	// 1→9, 2 keep, 3 delete (idx=1 >= len(to)=1), 4 keep.
	if len(r2) == 3 { pass = pass + 1 }
	if r2[0] == 9 { pass = pass + 1 }
	if r2[1] == 2 { pass = pass + 1 }
	if r2[2] == 4 { pass = pass + 1 }

	// Translate — empty from returns copy.
	var r3 []byte = bytes.Translate(new(3) []byte { 1, 2, 3 }, new(0) []byte {}, new(0) []byte {})
	if len(r3) == 3 { pass = pass + 1 }
	if r3[0] == 1 { pass = pass + 1 }

	// Translate — empty s.
	var r4 []byte = bytes.Translate(new(0) []byte {}, new(2) []byte { 1, 2 }, new(2) []byte { 9, 8 })
	if len(r4) == 0 { pass = pass + 1 }

	// Translate — no matches.
	var r5 []byte = bytes.Translate(new(3) []byte { 10, 20, 30 }, new(2) []byte { 1, 2 }, new(2) []byte { 9, 8 })
	if r5[0] == 10 { pass = pass + 1 }
	if r5[1] == 20 { pass = pass + 1 }
	if r5[2] == 30 { pass = pass + 1 }

	// Translate — delete all (from non-empty, to empty).
	var r6 []byte = bytes.Translate(new(3) []byte { 1, 2, 3 }, new(3) []byte { 1, 2, 3 }, new(0) []byte {})
	if len(r6) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
