package main
import "log"
import "crypto/hmac"

fun main() int {
	var pass int = 0

	// Both empty → true.
	if hmac.Equal("", "") { pass = pass + 1 }

	// Different lengths → false.
	if !hmac.Equal("a", "ab") { pass = pass + 1 }
	if !hmac.Equal("ab", "a") { pass = pass + 1 }
	if !hmac.Equal("", "x") { pass = pass + 1 }
	if !hmac.Equal("x", "") { pass = pass + 1 }

	// Identical → true.
	if hmac.Equal("hello", "hello") { pass = pass + 1 }
	if hmac.Equal("a", "a") { pass = pass + 1 }
	if hmac.Equal("longer string for testing", "longer string for testing") { pass = pass + 1 }

	// Differ at first byte → false.
	if !hmac.Equal("hello", "Hello") { pass = pass + 1 }

	// Differ at last byte → false.
	if !hmac.Equal("hello", "hellO") { pass = pass + 1 }

	// Differ in middle → false.
	if !hmac.Equal("hello", "heLlo") { pass = pass + 1 }

	// Completely different (same length) → false.
	if !hmac.Equal("abcde", "fghij") { pass = pass + 1 }

	// High-bit bytes via & 255 dodge.
	if hmac.Equal("\xff\xfe\xfd", "\xff\xfe\xfd") { pass = pass + 1 }
	if !hmac.Equal("\xff\xfe\xfd", "\xff\xfe\xfc") { pass = pass + 1 }

	// HMAC tag verification use case: golden vector cross-checked.
	var tag string = hmac.Sum256Hex("key", "message")
	if hmac.Equal(tag, hmac.Sum256Hex("key", "message")) { pass = pass + 1 }
	if !hmac.Equal(tag, hmac.Sum256Hex("key", "MESSAGE")) { pass = pass + 1 }
	if !hmac.Equal(tag, hmac.Sum256Hex("wrong-key", "message")) { pass = pass + 1 }

	// CSRF token / session token comparison.
	var t1 string = "abc123-csrf-token-xyz"
	var t2 string = "abc123-csrf-token-xyz"
	if hmac.Equal(t1, t2) { pass = pass + 1 }
	var t3 string = "abc123-csrf-token-XYZ"
	var t4 string = "abc123-csrf-token-xyz"
	if !hmac.Equal(t3, t4) { pass = pass + 1 }

	// Single-byte difference → false (does not short-circuit, but result is correct).
	if !hmac.Equal("aaaa", "aaab") { pass = pass + 1 }
	if !hmac.Equal("aaaaaaaaaa", "baaaaaaaaa") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
