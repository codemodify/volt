package main
import "log"
import "strings"

// Positive test: strings.IndexRune + strings.ContainsRune.

fun main() int {
	var pass int = 0

	// IndexRune ASCII.
	if strings.IndexRune("hello", "h") == 0 { pass = pass + 1 }
	if strings.IndexRune("hello", "l") == 2 { pass = pass + 1 }
	if strings.IndexRune("hello", "o") == 4 { pass = pass + 1 }
	if strings.IndexRune("hello", "z") == -1 { pass = pass + 1 }

	// Empty s.
	if strings.IndexRune("", "a") == -1 { pass = pass + 1 }

	// Empty r returns 0 (vacuous).
	if strings.IndexRune("hello", "") == 0 { pass = pass + 1 }

	// UTF-8 — find é in "caf\xC3\xA9".
	if strings.IndexRune("caf\xC3\xA9", "\xC3\xA9") == 3 { pass = pass + 1 }

	// 3-byte rune.
	if strings.IndexRune("a\xE4\xB8\x96b", "\xE4\xB8\x96") == 1 { pass = pass + 1 }

	// 4-byte emoji.
	if strings.IndexRune("ab\xF0\x9F\x98\x80cd", "\xF0\x9F\x98\x80") == 2 { pass = pass + 1 }

	// Don't match across rune boundaries (a 2-byte rune doesn't match if r is 1 byte).
	if strings.IndexRune("\xC3\xA9hello", "h") == 1 { pass = pass + 1 }   // skipping multi-byte

	// IndexRune doesn't match 1 byte against multi-byte rune.
	if strings.IndexRune("hello\xC3\xA9", "\xC3") == -1 { pass = pass + 1 }

	// ContainsRune.
	if strings.ContainsRune("hello", "l") { pass = pass + 1 }
	if !strings.ContainsRune("hello", "z") { pass = pass + 1 }
	if strings.ContainsRune("caf\xC3\xA9", "\xC3\xA9") { pass = pass + 1 }
	if !strings.ContainsRune("caf\xC3\xA9", "X") { pass = pass + 1 }

	// ContainsRune empty s.
	if !strings.ContainsRune("", "a") { pass = pass + 1 }

	// ContainsRune empty r is vacuously true.
	if strings.ContainsRune("hello", "") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
