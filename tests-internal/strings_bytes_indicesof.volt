package main
import "log"
import "strings"
import "bytes"

// Positive test: strings.IndicesOf + bytes.IndicesOf.

fun main() int {
	var pass int = 0

	// strings.IndicesOf — single match.
	var p1 []int = strings.IndicesOf("hello world", "world")
	if len(p1) == 1 { pass = pass + 1 }
	if p1[0] == 6 { pass = pass + 1 }

	// strings.IndicesOf — multiple non-overlapping.
	var p2 []int = strings.IndicesOf("ababab", "ab")
	if len(p2) == 3 { pass = pass + 1 }
	if p2[0] == 0 { pass = pass + 1 }
	if p2[1] == 2 { pass = pass + 1 }
	if p2[2] == 4 { pass = pass + 1 }

	// strings.IndicesOf — non-overlapping rule.
	var p3 []int = strings.IndicesOf("aaaa", "aa")
	if len(p3) == 2 { pass = pass + 1 }
	if p3[0] == 0 { pass = pass + 1 }
	if p3[1] == 2 { pass = pass + 1 }

	// strings.IndicesOf — no match.
	var p4 []int = strings.IndicesOf("hello", "xyz")
	if len(p4) == 0 { pass = pass + 1 }

	// strings.IndicesOf — empty sub.
	var p5 []int = strings.IndicesOf("hello", "")
	if len(p5) == 0 { pass = pass + 1 }

	// strings.IndicesOf — empty s.
	var p6 []int = strings.IndicesOf("", "ab")
	if len(p6) == 0 { pass = pass + 1 }

	// strings.IndicesOf — sub longer than s.
	var p7 []int = strings.IndicesOf("ab", "abc")
	if len(p7) == 0 { pass = pass + 1 }

	// strings.IndicesOf — multi-char sub with gaps.
	var p8 []int = strings.IndicesOf("a-b-a-b-a", "a-b")
	if len(p8) == 2 { pass = pass + 1 }
	if p8[0] == 0 { pass = pass + 1 }
	if p8[1] == 4 { pass = pass + 1 }

	// bytes.IndicesOf — basic.
	var b1 []int = bytes.IndicesOf(new(6) []byte { 1, 2, 3, 1, 2, 3 }, new(3) []byte { 1, 2, 3 })
	if len(b1) == 2 { pass = pass + 1 }
	if b1[0] == 0 { pass = pass + 1 }
	if b1[1] == 3 { pass = pass + 1 }

	// bytes.IndicesOf — empty sub.
	var b2 []int = bytes.IndicesOf(new(3) []byte { 1, 2, 3 }, new(0) []byte {})
	if len(b2) == 0 { pass = pass + 1 }

	// bytes.IndicesOf — no match.
	var b3 []int = bytes.IndicesOf(new(3) []byte { 1, 2, 3 }, new(2) []byte { 9, 9 })
	if len(b3) == 0 { pass = pass + 1 }

	// Count cross-check: len(IndicesOf) == strings.Count.
	if len(strings.IndicesOf("ababab", "ab")) == strings.Count("ababab", "ab") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
