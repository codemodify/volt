package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// JsonUnescape — pass through.
	if strings.JsonUnescape("hello") == "hello" { pass = pass + 1 }
	if strings.JsonUnescape("") == "" { pass = pass + 1 }

	// Each mandatory escape.
	if strings.JsonUnescape("\\\\") == "\\" { pass = pass + 1 }
	if strings.JsonUnescape("\\\"") == "\"" { pass = pass + 1 }
	if strings.JsonUnescape("\\/") == "/" { pass = pass + 1 }
	if strings.JsonUnescape("\\n") == "\n" { pass = pass + 1 }
	if strings.JsonUnescape("\\r") == "\r" { pass = pass + 1 }
	if strings.JsonUnescape("\\t") == "\t" { pass = pass + 1 }
	if strings.JsonUnescape("\\f") == "\f" { pass = pass + 1 }
	if strings.JsonUnescape("\\b") == "\b" { pass = pass + 1 }

	// \u for ASCII.
	if strings.JsonUnescape("\\u0041") == "A" { pass = pass + 1 }
	if strings.JsonUnescape("\\u0000") == "\x00" { pass = pass + 1 }

	// \u for Latin-1 (2-byte UTF-8).
	if strings.JsonUnescape("\\u00e9") == "\xc3\xa9" { pass = pass + 1 }   // é

	// \u for BMP (3-byte UTF-8). U+00A2 (¢) = 0xC2, 0xA2.
	if strings.JsonUnescape("\\u00a2") == "\xc2\xa2" { pass = pass + 1 }   // ¢

	// \u for higher BMP. U+0939 = 0xE0 0xA4 0xB9. 0939 / 4096 = 0, +224 = 224 (0xE0). (0939 / 64) % 64 = 14 (after dividing 2361/64 = 36, 36 % 64 = 36, 128+36=164=0xA4). 2361 % 64 = 57 (128+57=185=0xB9).
	if strings.JsonUnescape("\\u0939") == "\xe0\xa4\xb9" { pass = pass + 1 }

	// Bad escapes pass through literally.
	if strings.JsonUnescape("\\x") == "\\x" { pass = pass + 1 }
	if strings.JsonUnescape("\\u00X") == "\\u00X" { pass = pass + 1 }    // bad hex
	if strings.JsonUnescape("\\u00") == "\\u00" { pass = pass + 1 }      // too short

	// Trailing backslash.
	if strings.JsonUnescape("\\") == "\\" { pass = pass + 1 }

	// Mixed.
	if strings.JsonUnescape("line1\\nline2") == "line1\nline2" { pass = pass + 1 }
	if strings.JsonUnescape("say \\\"hi\\\"") == "say \"hi\"" { pass = pass + 1 }

	// Roundtrip: JsonUnescape(JsonEscape(s)) == s.
	if strings.JsonUnescape(strings.JsonEscape("a\"b\\c\nd")) == "a\"b\\c\nd" { pass = pass + 1 }
	if strings.JsonUnescape(strings.JsonEscape("\x00\x01\x1f")) == "\x00\x01\x1f" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
