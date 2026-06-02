package main
import "log"
import "strings"

// Positive test: strings.CountRune + strings.LastIndexRune.

fun main() int {
	var pass int = 0

	// CountRune ASCII.
	if strings.CountRune("hello", "l") == 2 { pass = pass + 1 }
	if strings.CountRune("hello", "h") == 1 { pass = pass + 1 }
	if strings.CountRune("hello", "z") == 0 { pass = pass + 1 }
	if strings.CountRune("xxxxxx", "x") == 6 { pass = pass + 1 }

	// Empty s.
	if strings.CountRune("", "a") == 0 { pass = pass + 1 }
	// Empty r returns RuneCount + 1.
	if strings.CountRune("hello", "") == 6 { pass = pass + 1 }
	if strings.CountRune("", "") == 1 { pass = pass + 1 }

	// UTF-8.
	if strings.CountRune("caf\xC3\xA9 et caf\xC3\xA9", "\xC3\xA9") == 2 { pass = pass + 1 }
	if strings.CountRune("a\xE4\xB8\x96b\xE4\xB8\x96c", "\xE4\xB8\x96") == 2 { pass = pass + 1 }
	if strings.CountRune("\xF0\x9F\x98\x80\xF0\x9F\x98\x80\xF0\x9F\x98\x80", "\xF0\x9F\x98\x80") == 3 { pass = pass + 1 }

	// Single byte query doesn't match multi-byte rune fragment.
	if strings.CountRune("caf\xC3\xA9", "\xC3") == 0 { pass = pass + 1 }

	// LastIndexRune ASCII.
	if strings.LastIndexRune("hello", "l") == 3 { pass = pass + 1 }
	if strings.LastIndexRune("hello", "h") == 0 { pass = pass + 1 }
	if strings.LastIndexRune("hello", "o") == 4 { pass = pass + 1 }
	if strings.LastIndexRune("hello", "z") == -1 { pass = pass + 1 }

	// Empty s.
	if strings.LastIndexRune("", "a") == -1 { pass = pass + 1 }

	// Empty r → RuneCount(s) (Go convention).
	if strings.LastIndexRune("hello", "") == 5 { pass = pass + 1 }
	if strings.LastIndexRune("", "") == 0 { pass = pass + 1 }

	// UTF-8.
	if strings.LastIndexRune("caf\xC3\xA9 caf\xC3\xA9", "\xC3\xA9") == 8 { pass = pass + 1 }   // 8 runes total, last é at rune 8
	if strings.LastIndexRune("a\xE4\xB8\x96b\xE4\xB8\x96c", "\xE4\xB8\x96") == 3 { pass = pass + 1 }

	// Single byte query doesn't match continuation byte.
	if strings.LastIndexRune("caf\xC3\xA9", "\xA9") == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
