package main
import "log"
import "strings"

// Positive test: strings.IsValidUtf8 + strings.RuneCount.

fun main() int {
	var pass int = 0

	// IsValidUtf8 ASCII.
	if strings.IsValidUtf8("") { pass = pass + 1 }
	if strings.IsValidUtf8("hello") { pass = pass + 1 }
	if strings.IsValidUtf8("ABC 123 !@#") { pass = pass + 1 }
	if strings.IsValidUtf8("\x7f") { pass = pass + 1 }

	// Valid 2-byte UTF-8: 'é' is C3 A9.
	if strings.IsValidUtf8("café") { pass = pass + 1 }

	// Valid 3-byte UTF-8: '世' is E4 B8 96.
	if strings.IsValidUtf8("世界") { pass = pass + 1 }

	// Valid 4-byte UTF-8: '😀' is F0 9F 98 80.
	if strings.IsValidUtf8("\xF0\x9F\x98\x80") { pass = pass + 1 }

	// Invalid — lone continuation byte.
	if !strings.IsValidUtf8("\x80") { pass = pass + 1 }
	if !strings.IsValidUtf8("a\x80b") { pass = pass + 1 }

	// Invalid — truncated multi-byte (lead byte but no continuation).
	if !strings.IsValidUtf8("\xC3") { pass = pass + 1 }
	if !strings.IsValidUtf8("\xE4\xB8") { pass = pass + 1 }   // 3-byte missing 1
	if !strings.IsValidUtf8("\xF0\x9F\x98") { pass = pass + 1 } // 4-byte missing 1

	// Invalid — 5-byte lead (0xF8+).
	if !strings.IsValidUtf8("\xF8\x80\x80\x80\x80") { pass = pass + 1 }

	// Invalid — bad continuation byte (not 10xxxxxx).
	if !strings.IsValidUtf8("\xC3\x41") { pass = pass + 1 }   // 0x41 isn't continuation

	// Mixed ASCII + valid UTF-8.
	if strings.IsValidUtf8("hello, 世界") { pass = pass + 1 }

	// RuneCount.
	if strings.RuneCount("") == 0 { pass = pass + 1 }
	if strings.RuneCount("hello") == 5 { pass = pass + 1 }   // ASCII
	if strings.RuneCount("café") == 4 { pass = pass + 1 }    // 5 bytes, 4 runes
	if strings.RuneCount("世界") == 2 { pass = pass + 1 }   // 6 bytes, 2 runes
	if strings.RuneCount("\xF0\x9F\x98\x80") == 1 { pass = pass + 1 }   // 1 emoji
	if strings.RuneCount("a\xF0\x9F\x98\x80b") == 3 { pass = pass + 1 } // a + emoji + b

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
