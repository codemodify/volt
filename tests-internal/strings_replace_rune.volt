package main
import "log"
import "strings"

// Positive test: strings.ReplaceRune.

fun main() int {
	var pass int = 0

	// ASCII rune replace.
	if strings.ReplaceRune("hello", "l", "X") == "heXXo" { pass = pass + 1 }
	if strings.ReplaceRune("aaaa", "a", "b") == "bbbb" { pass = pass + 1 }
	if strings.ReplaceRune("xyz", "q", "Q") == "xyz" { pass = pass + 1 }   // no match

	// Empty inputs.
	if strings.ReplaceRune("", "a", "b") == "" { pass = pass + 1 }
	if strings.ReplaceRune("hello", "", "X") == "hello" { pass = pass + 1 }   // empty old → unchanged

	// Replace with longer string.
	if strings.ReplaceRune("hi", "i", "ooo") == "hooo" { pass = pass + 1 }
	// Replace with empty (deletion).
	if strings.ReplaceRune("hello", "l", "") == "heo" { pass = pass + 1 }

	// UTF-8 — replace é with E.
	if strings.ReplaceRune("caf\xC3\xA9", "\xC3\xA9", "E") == "cafE" { pass = pass + 1 }
	// Replace ASCII with multi-byte.
	if strings.ReplaceRune("cafe", "e", "\xC3\xA9") == "caf\xC3\xA9" { pass = pass + 1 }
	// Replace multi-byte with multi-byte.
	if strings.ReplaceRune("caf\xC3\xA9 caf\xC3\xA9", "\xC3\xA9", "\xE4\xB8\x96") == "caf\xE4\xB8\x96 caf\xE4\xB8\x96" { pass = pass + 1 }

	// Don't accidentally match a multi-byte byte against a single-byte query.
	if strings.ReplaceRune("caf\xC3\xA9", "\xC3", "X") == "caf\xC3\xA9" { pass = pass + 1 }   // single byte query doesn't hit multi-byte rune

	// Replace single ASCII with single ASCII.
	if strings.ReplaceRune("a-b-c", "-", "_") == "a_b_c" { pass = pass + 1 }

	// All match.
	if strings.ReplaceRune("zzz", "z", "y") == "yyy" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
