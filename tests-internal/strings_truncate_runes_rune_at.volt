package main
import "log"
import "strings"

// Positive test: strings.TruncateRunes + strings.RuneAt.

fun main() int {
	var pass int = 0

	// TruncateRunes — ASCII fits.
	if strings.TruncateRunes("hi", 10, "...") == "hi" { pass = pass + 1 }
	// ASCII exact.
	if strings.TruncateRunes("hello", 5, "...") == "hello" { pass = pass + 1 }
	// ASCII clamp + ellipsis.
	if strings.TruncateRunes("hello world", 5, "...") == "hello..." { pass = pass + 1 }
	// ASCII clamp without ellipsis.
	if strings.TruncateRunes("hello world", 5, "") == "hello" { pass = pass + 1 }
	// maxRunes 0 / negative.
	if strings.TruncateRunes("hi", 0, "...") == "" { pass = pass + 1 }
	if strings.TruncateRunes("hi", -1, "...") == "" { pass = pass + 1 }
	// Empty input.
	if strings.TruncateRunes("", 5, "...") == "" { pass = pass + 1 }

	// UTF-8 — café (4 runes, 5 bytes), clamp to 2 runes.
	if strings.TruncateRunes("caf\xC3\xA9", 2, "...") == "ca..." { pass = pass + 1 }
	// Clamp at exact multi-byte boundary (4 runes, no truncation).
	if strings.TruncateRunes("caf\xC3\xA9", 4, "...") == "caf\xC3\xA9" { pass = pass + 1 }
	// Clamp to 3 runes — includes 'f' before é.
	if strings.TruncateRunes("caf\xC3\xA9hi", 3, ">") == "caf>" { pass = pass + 1 }
	// Multi-byte split correctly.
	if strings.TruncateRunes("\xE4\xB8\x96\xE7\x95\x8C\xE4\xB8\x96", 2, "...") == "\xE4\xB8\x96\xE7\x95\x8C..." { pass = pass + 1 }

	// RuneAt — ASCII.
	if strings.RuneAt("hello", 0) == "h" { pass = pass + 1 }
	if strings.RuneAt("hello", 1) == "e" { pass = pass + 1 }
	if strings.RuneAt("hello", 4) == "o" { pass = pass + 1 }

	// Out-of-range.
	if strings.RuneAt("hello", 5) == "" { pass = pass + 1 }
	if strings.RuneAt("hello", 100) == "" { pass = pass + 1 }
	if strings.RuneAt("hello", -1) == "" { pass = pass + 1 }

	// UTF-8.
	if strings.RuneAt("\xC3\xA9abc", 0) == "\xC3\xA9" { pass = pass + 1 }
	if strings.RuneAt("\xC3\xA9abc", 1) == "a" { pass = pass + 1 }
	if strings.RuneAt("a\xC3\xA9b", 1) == "\xC3\xA9" { pass = pass + 1 }
	if strings.RuneAt("a\xC3\xA9b", 2) == "b" { pass = pass + 1 }

	// 4-byte emoji.
	if strings.RuneAt("hi\xF0\x9F\x98\x80", 2) == "\xF0\x9F\x98\x80" { pass = pass + 1 }

	// Empty s.
	if strings.RuneAt("", 0) == "" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
