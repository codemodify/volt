package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.OnlyAscii("") == "" { pass = pass + 1 }

	// All-ASCII passes through unchanged.
	if strings.OnlyAscii("hello world") == "hello world" { pass = pass + 1 }
	if strings.OnlyAscii("abc123!@#") == "abc123!@#" { pass = pass + 1 }

	// Control bytes (< 32) are kept too — they're still ASCII.
	if strings.OnlyAscii("a\nb\tc") == "a\nb\tc" { pass = pass + 1 }
	if strings.OnlyAscii("\x00\x01\x7f") == "\x00\x01\x7f" { pass = pass + 1 }   // NUL, SOH, DEL

	// 0x7F (127) is the boundary — kept.
	if strings.OnlyAscii("\x7f") == "\x7f" { pass = pass + 1 }

	// 0x80 (128) is the first non-ASCII — stripped.
	if strings.OnlyAscii("a\x80b") == "ab" { pass = pass + 1 }

	// UTF-8 multi-byte é (0xc3 0xa9) — both bytes stripped.
	if strings.OnlyAscii("caf\xc3\xa9") == "caf" { pass = pass + 1 }

	// Multiple UTF-8 codepoints interleaved with ASCII.
	if strings.OnlyAscii("a\xc3\xa9b\xc3\xa9c") == "abc" { pass = pass + 1 }

	// All-non-ASCII → empty.
	if strings.OnlyAscii("\xc3\xa9\xc3\xa9") == "" { pass = pass + 1 }

	// 0xFF (255) — non-ASCII, stripped.
	if strings.OnlyAscii("x\xff\xffy") == "xy" { pass = pass + 1 }

	// Mixed text with currency / quotes that are UTF-8 (€ is 0xe2 0x82 0xac).
	if strings.OnlyAscii("$100 \xe2\x82\xac50") == "$100 50" { pass = pass + 1 }

	// Idempotent on ASCII-only input.
	var ascii string = "Hello, World!"
	if strings.OnlyAscii(strings.OnlyAscii(ascii)) == ascii { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
