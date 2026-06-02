package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// Empty.
	var empty []byte = new(0) []byte {}
	var r1 []byte = bytes.SortBytes(empty)
	if len(r1) == 0 { pass = pass + 1 }

	// Single byte.
	var one []byte = new(1) []byte { 65 }
	var r2 []byte = bytes.SortBytes(one)
	if len(r2) == 1 { pass = pass + 1 }
	if r2[0] == 65 { pass = pass + 1 }

	// Already sorted.
	var asc []byte = new(3) []byte { 1, 2, 3 }
	var r3 []byte = bytes.SortBytes(asc)
	if r3[0] == 1 { pass = pass + 1 }
	if r3[1] == 2 { pass = pass + 1 }
	if r3[2] == 3 { pass = pass + 1 }

	// Reverse-sorted reorders.
	var desc []byte = new(4) []byte { 9, 7, 5, 3 }
	var r4 []byte = bytes.SortBytes(desc)
	if r4[0] == 3 { pass = pass + 1 }
	if r4[1] == 5 { pass = pass + 1 }
	if r4[2] == 7 { pass = pass + 1 }
	if r4[3] == 9 { pass = pass + 1 }

	// Duplicates preserved.
	var dup []byte = new(6) []byte { 5, 1, 5, 1, 5, 1 }
	var r5 []byte = bytes.SortBytes(dup)
	if len(r5) == 6 { pass = pass + 1 }
	if r5[0] == 1 { pass = pass + 1 }
	if r5[2] == 1 { pass = pass + 1 }
	if r5[3] == 5 { pass = pass + 1 }
	if r5[5] == 5 { pass = pass + 1 }

	// "cba" → "abc".
	var cba []byte = new(3) []byte { 99, 98, 97 }
	var r6 []byte = bytes.SortBytes(cba)
	if r6[0] == 97 { pass = pass + 1 }
	if r6[1] == 98 { pass = pass + 1 }
	if r6[2] == 99 { pass = pass + 1 }

	// Result length matches input — use ascii-range bytes (volt's
	// byte is signed; values > 127 wrap, so comparing to e.g. 200
	// fails as signed sign-extension makes it -56).
	var arbitrary []byte = new(7) []byte { 50, 10, 120, 5, 100, 60, 80 }
	var r7 []byte = bytes.SortBytes(arbitrary)
	if len(r7) == 7 { pass = pass + 1 }
	if r7[0] == 5 { pass = pass + 1 }
	if r7[6] == 120 { pass = pass + 1 }

	// Idempotent — sort fresh data then sort again.
	var fresh []byte = new(7) []byte { 50, 10, 120, 5, 100, 60, 80 }
	var sorted1 []byte = bytes.SortBytes(fresh)
	var sorted2 []byte = bytes.SortBytes(sorted1)
	if len(sorted2) == 7 { pass = pass + 1 }
	if sorted2[0] == 5 { pass = pass + 1 }
	if sorted2[6] == 120 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
