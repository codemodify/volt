package main
import "log"
import "strings"

// Positive test: strings.Translate + strings.RemoveChars.

fun main() int {
	var pass int = 0

	// Translate — straight substitution.
	if strings.Translate("hello", "el", "ip") == "hippo" { pass = pass + 1 }
	if strings.Translate("abc", "a", "z") == "zbc" { pass = pass + 1 }
	if strings.Translate("abc", "abc", "xyz") == "xyz" { pass = pass + 1 }

	// Translate — from longer than to → extra mappings delete.
	if strings.Translate("abc", "ab", "") == "c" { pass = pass + 1 }
	if strings.Translate("abc", "a", "") == "bc" { pass = pass + 1 }
	if strings.Translate("abcabc", "ac", "X") == "XbXb" { pass = pass + 1 }
	// "ac"/"X": 'a'→'X', 'c' has no corresponding (idx=1 >= len(to)=1), delete.

	// Translate — no matches.
	if strings.Translate("hello", "xyz", "abc") == "hello" { pass = pass + 1 }

	// Translate — empty inputs.
	if strings.Translate("", "abc", "xyz") == "" { pass = pass + 1 }
	if strings.Translate("hello", "", "xyz") == "hello" { pass = pass + 1 }
	if strings.Translate("", "", "") == "" { pass = pass + 1 }

	// Translate — case swap shortcut (each lowercase → uppercase via index).
	if strings.Translate("hello", "helo", "HELO") == "HELLO" { pass = pass + 1 }

	// Translate — rot13-like step (just a/b swap).
	if strings.Translate("aabbcc", "ab", "ba") == "bbaacc" { pass = pass + 1 }

	// RemoveChars — basic.
	if strings.RemoveChars("hello world", " ") == "helloworld" { pass = pass + 1 }
	if strings.RemoveChars("hello world", "lo") == "he wrd" { pass = pass + 1 }
	if strings.RemoveChars("12345", "13") == "245" { pass = pass + 1 }

	// RemoveChars — no chars match.
	if strings.RemoveChars("abc", "xyz") == "abc" { pass = pass + 1 }

	// RemoveChars — empty inputs.
	if strings.RemoveChars("", "abc") == "" { pass = pass + 1 }
	if strings.RemoveChars("hello", "") == "hello" { pass = pass + 1 }

	// RemoveChars — strip all.
	if strings.RemoveChars("aaa", "a") == "" { pass = pass + 1 }

	// RemoveChars — interior + edge stripping.
	if strings.RemoveChars("a.b.c", ".") == "abc" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
