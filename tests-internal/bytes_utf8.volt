package main
import "log"
import "bytes"

// Positive test: bytes.IsValidUtf8 + bytes.RuneCount.

fun main() int {
	var pass int = 0

	// IsValidUtf8 — empty.
	var em []byte = new(0) []byte{}
	if bytes.IsValidUtf8(em) { pass = pass + 1 }

	// ASCII.
	var ascii []byte = new(5) []byte{104, 101, 108, 108, 111}   // "hello"
	if bytes.IsValidUtf8(ascii) { pass = pass + 1 }

	// 2-byte é (0xC3 0xA9).
	var two []byte = new(2) []byte{0xC3, 0xA9}
	if bytes.IsValidUtf8(two) { pass = pass + 1 }

	// 3-byte 世 (0xE4 0xB8 0x96).
	var three []byte = new(3) []byte{0xE4, 0xB8, 0x96}
	if bytes.IsValidUtf8(three) { pass = pass + 1 }

	// 4-byte emoji 😀 (0xF0 0x9F 0x98 0x80).
	var four []byte = new(4) []byte{0xF0, 0x9F, 0x98, 0x80}
	if bytes.IsValidUtf8(four) { pass = pass + 1 }

	// Lone continuation.
	var bad1 []byte = new(1) []byte{0x80}
	if !bytes.IsValidUtf8(bad1) { pass = pass + 1 }

	// Truncated multi-byte.
	var bad2 []byte = new(1) []byte{0xC3}
	if !bytes.IsValidUtf8(bad2) { pass = pass + 1 }

	// Invalid 5-byte lead.
	var bad3 []byte = new(5) []byte{0xF8, 0x80, 0x80, 0x80, 0x80}
	if !bytes.IsValidUtf8(bad3) { pass = pass + 1 }

	// Bad continuation.
	var bad4 []byte = new(2) []byte{0xC3, 0x41}
	if !bytes.IsValidUtf8(bad4) { pass = pass + 1 }

	// RuneCount — empty.
	if bytes.RuneCount(em) == 0 { pass = pass + 1 }
	// ASCII.
	if bytes.RuneCount(ascii) == 5 { pass = pass + 1 }
	// Single 2-byte rune.
	if bytes.RuneCount(two) == 1 { pass = pass + 1 }
	// Single 3-byte rune.
	if bytes.RuneCount(three) == 1 { pass = pass + 1 }
	// Single 4-byte rune.
	if bytes.RuneCount(four) == 1 { pass = pass + 1 }

	// Mixed: a + é + 世 + 😀.
	var mixed []byte = new(10) []byte{0x61, 0xC3, 0xA9, 0xE4, 0xB8, 0x96, 0xF0, 0x9F, 0x98, 0x80}
	if bytes.IsValidUtf8(mixed) { pass = pass + 1 }
	if bytes.RuneCount(mixed) == 4 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
