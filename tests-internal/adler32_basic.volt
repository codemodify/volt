package main
import "log"
import "hash/adler32"

// Positive test: adler32.Checksum. Cross-checked against Python's
// zlib.adler32.

fun main() int {
	var pass int = 0

	// Empty → 1 (initial value of a).
	if adler32.Checksum("") == 1 { pass = pass + 1 }

	// "a" → 6422626 (0x00620062)
	if adler32.Checksum("a") == 6422626 { pass = pass + 1 }

	// "abc" → 38600999
	if adler32.Checksum("abc") == 38600999 { pass = pass + 1 }

	// "hello world" → 436929629
	if adler32.Checksum("hello world") == 436929629 { pass = pass + 1 }

	// Pangram → 1541148634
	if adler32.Checksum("The quick brown fox jumps over the lazy dog") == 1541148634 { pass = pass + 1 }

	// Determinism.
	var h1 int = adler32.Checksum("repeatable")
	var h2 int = adler32.Checksum("repeatable")
	if h1 == h2 { pass = pass + 1 }

	// Different content → different hash.
	var h3 int = adler32.Checksum("alpha")
	var h4 int = adler32.Checksum("beta")
	if h3 != h4 { pass = pass + 1 }

	log.Println("pass=%d hello=%d", pass, adler32.Checksum("hello world"))
	if pass == 7 { ret 42 }
	ret 0
}
