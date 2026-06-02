package main
import "log"
import "strings"

// Positive test: strings.RuneReverse + strings.ByteIndexRune.

fun main() int {
	var pass int = 0

	// RuneReverse ASCII.
	if strings.RuneReverse("hello") == "olleh" { pass = pass + 1 }
	if strings.RuneReverse("a") == "a" { pass = pass + 1 }
	if strings.RuneReverse("") == "" { pass = pass + 1 }
	if strings.RuneReverse("ab") == "ba" { pass = pass + 1 }

	// RuneReverse — palindrome unchanged.
	if strings.RuneReverse("racecar") == "racecar" { pass = pass + 1 }

	// RuneReverse — multi-byte. café (5 bytes) → écaf (still 5 bytes).
	if strings.RuneReverse("caf\xC3\xA9") == "\xC3\xA9fac" { pass = pass + 1 }

	// RuneReverse — bytes within a rune stay in order.
	// "\xE4\xB8\x96" is one rune (世). Reversing "\xE4\xB8\x96abc" → "cba\xE4\xB8\x96".
	if strings.RuneReverse("\xE4\xB8\x96abc") == "cba\xE4\xB8\x96" { pass = pass + 1 }

	// RuneReverse — emoji + ASCII.
	if strings.RuneReverse("a\xF0\x9F\x98\x80b") == "b\xF0\x9F\x98\x80a" { pass = pass + 1 }

	// Round-trip: RuneReverse(RuneReverse(s)) == s.
	if strings.RuneReverse(strings.RuneReverse("hello world")) == "hello world" { pass = pass + 1 }
	if strings.RuneReverse(strings.RuneReverse("caf\xC3\xA9")) == "caf\xC3\xA9" { pass = pass + 1 }

	// ByteIndexRune — ASCII.
	if strings.ByteIndexRune("hello", 0) == 0 { pass = pass + 1 }
	if strings.ByteIndexRune("hello", 1) == 1 { pass = pass + 1 }
	if strings.ByteIndexRune("hello", 4) == 4 { pass = pass + 1 }
	if strings.ByteIndexRune("hello", 5) == 5 { pass = pass + 1 }   // one past

	// Out of range.
	if strings.ByteIndexRune("hello", 6) == -1 { pass = pass + 1 }
	if strings.ByteIndexRune("hello", -1) == -1 { pass = pass + 1 }

	// UTF-8 — "caf\xC3\xA9" 4 runes / 5 bytes.
	if strings.ByteIndexRune("caf\xC3\xA9", 0) == 0 { pass = pass + 1 }
	if strings.ByteIndexRune("caf\xC3\xA9", 1) == 1 { pass = pass + 1 }
	if strings.ByteIndexRune("caf\xC3\xA9", 2) == 2 { pass = pass + 1 }
	if strings.ByteIndexRune("caf\xC3\xA9", 3) == 3 { pass = pass + 1 }
	if strings.ByteIndexRune("caf\xC3\xA9", 4) == 5 { pass = pass + 1 }   // one past last rune

	// 3-byte rune.
	if strings.ByteIndexRune("a\xE4\xB8\x96b", 1) == 1 { pass = pass + 1 }
	if strings.ByteIndexRune("a\xE4\xB8\x96b", 2) == 4 { pass = pass + 1 }   // 'b' starts at byte 4

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
