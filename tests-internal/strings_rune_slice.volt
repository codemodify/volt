package main
import "log"
import "strings"

// Positive test: strings.RuneSlice.

fun main() int {
	var pass int = 0

	// ASCII basic.
	if strings.RuneSlice("hello", 0, 5) == "hello" { pass = pass + 1 }
	if strings.RuneSlice("hello", 0, 3) == "hel" { pass = pass + 1 }
	if strings.RuneSlice("hello", 1, 4) == "ell" { pass = pass + 1 }
	if strings.RuneSlice("hello", 2, 5) == "llo" { pass = pass + 1 }
	if strings.RuneSlice("hello", 4, 5) == "o" { pass = pass + 1 }

	// Empty result conditions.
	if strings.RuneSlice("hello", 3, 3) == "" { pass = pass + 1 }
	if strings.RuneSlice("hello", 4, 2) == "" { pass = pass + 1 }   // hi < lo
	if strings.RuneSlice("", 0, 5) == "" { pass = pass + 1 }
	if strings.RuneSlice("hello", 10, 20) == "" { pass = pass + 1 } // lo past end

	// Out-of-range clamps.
	if strings.RuneSlice("hello", -3, 2) == "he" { pass = pass + 1 }   // negative lo
	if strings.RuneSlice("hello", 2, 100) == "llo" { pass = pass + 1 } // hi past end

	// UTF-8 — "caf\xC3\xA9" is 4 runes, 5 bytes.
	if strings.RuneSlice("caf\xC3\xA9", 0, 4) == "caf\xC3\xA9" { pass = pass + 1 }
	if strings.RuneSlice("caf\xC3\xA9", 0, 3) == "caf" { pass = pass + 1 }
	if strings.RuneSlice("caf\xC3\xA9", 3, 4) == "\xC3\xA9" { pass = pass + 1 }
	if strings.RuneSlice("caf\xC3\xA9", 1, 4) == "af\xC3\xA9" { pass = pass + 1 }

	// 3-byte runes: "\xE4\xB8\x96\xE7\x95\x8C" is 2 runes (世界), 6 bytes.
	if strings.RuneSlice("\xE4\xB8\x96\xE7\x95\x8C", 0, 1) == "\xE4\xB8\x96" { pass = pass + 1 }
	if strings.RuneSlice("\xE4\xB8\x96\xE7\x95\x8C", 1, 2) == "\xE7\x95\x8C" { pass = pass + 1 }

	// 4-byte emoji.
	if strings.RuneSlice("a\xF0\x9F\x98\x80b", 1, 2) == "\xF0\x9F\x98\x80" { pass = pass + 1 }
	if strings.RuneSlice("a\xF0\x9F\x98\x80b", 0, 3) == "a\xF0\x9F\x98\x80b" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
