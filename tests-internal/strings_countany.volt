package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Vowel count.
	if strings.CountAny("hello world", "aeiou") == 3 { pass = pass + 1 }

	// Punctuation count.
	if strings.CountAny("hi! how, are you?", "!?.,;:") == 3 { pass = pass + 1 }

	// All chars match.
	if strings.CountAny("aaaa", "a") == 4 { pass = pass + 1 }
	if strings.CountAny("aaaa", "abc") == 4 { pass = pass + 1 }

	// None match.
	if strings.CountAny("hello", "xyz") == 0 { pass = pass + 1 }

	// Empty inputs.
	if strings.CountAny("", "abc") == 0 { pass = pass + 1 }
	if strings.CountAny("hello", "") == 0 { pass = pass + 1 }
	if strings.CountAny("", "") == 0 { pass = pass + 1 }

	// Whitespace count.
	if strings.CountAny("a b c\td\n", " \t\n") == 4 { pass = pass + 1 }

	// Single-char-set.
	if strings.CountAny("Hello, World!", ",") == 1 { pass = pass + 1 }
	if strings.CountAny("Hello, World!", "l") == 3 { pass = pass + 1 }

	// Repeated chars in `chars` don't double-count.
	if strings.CountAny("hello", "ll") == 2 { pass = pass + 1 }    // matches 'l' twice in s, 'll' in chars deduped

	// Digit count.
	if strings.CountAny("abc123def456", "0123456789") == 6 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
