package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// "hello world" (11 bytes).
	var hw []byte = new(11) []byte { 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100 }

	// Basic range — "hello".
	var r1 []byte = bytes.Slice(hw, 0, 5)
	if len(r1) == 5 { pass = pass + 1 }
	if r1[0] == 104 { pass = pass + 1 }
	if r1[4] == 111 { pass = pass + 1 }

	// "world".
	var r2 []byte = bytes.Slice(hw, 6, 11)
	if len(r2) == 5 { pass = pass + 1 }
	if r2[0] == 119 { pass = pass + 1 }
	if r2[4] == 100 { pass = pass + 1 }

	// Full range.
	var r3 []byte = bytes.Slice(hw, 0, 11)
	if len(r3) == 11 { pass = pass + 1 }

	// Empty (hi == lo).
	var r4 []byte = bytes.Slice(hw, 3, 3)
	if len(r4) == 0 { pass = pass + 1 }

	// Empty (hi < lo).
	var r5 []byte = bytes.Slice(hw, 5, 2)
	if len(r5) == 0 { pass = pass + 1 }

	// Empty input.
	var empty []byte = new(0) []byte {}
	var r6 []byte = bytes.Slice(empty, 0, 5)
	if len(r6) == 0 { pass = pass + 1 }

	// Negative lo clamps to 0.
	var r7 []byte = bytes.Slice(hw, -5, 5)
	if len(r7) == 5 { pass = pass + 1 }
	if r7[0] == 104 { pass = pass + 1 }

	// Overlarge hi clamps to len.
	var r8 []byte = bytes.Slice(hw, 6, 100)
	if len(r8) == 5 { pass = pass + 1 }
	if r8[0] == 119 { pass = pass + 1 }

	// Both clamp.
	var r9 []byte = bytes.Slice(hw, -100, 100)
	if len(r9) == 11 { pass = pass + 1 }

	// Use case — find separator with IndexByte, then Slice around it.
	var conf []byte = new(11) []byte { 110, 97, 109, 101, 61, 97, 108, 105, 99, 101, 33 }   // "name=alice!"
	var eq int = bytes.IndexByte(conf, 61)
	if eq == 4 { pass = pass + 1 }
	var key []byte = bytes.Slice(conf, 0, eq)
	if len(key) == 4 { pass = pass + 1 }
	if key[0] == 110 { pass = pass + 1 }
	var val []byte = bytes.Slice(conf, eq + 1, len(conf))
	if len(val) == 6 { pass = pass + 1 }
	if val[0] == 97 { pass = pass + 1 }    // 'a'

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
