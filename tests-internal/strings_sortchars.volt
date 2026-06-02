package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty stays empty.
	if strings.SortChars("") == "" { pass = pass + 1 }

	// Single char stays unchanged.
	if strings.SortChars("x") == "x" { pass = pass + 1 }

	// Already sorted.
	if strings.SortChars("abc") == "abc" { pass = pass + 1 }
	if strings.SortChars("0123") == "0123" { pass = pass + 1 }

	// Reverse-sorted reorders ascending.
	if strings.SortChars("cba") == "abc" { pass = pass + 1 }
	if strings.SortChars("dcba") == "abcd" { pass = pass + 1 }

	// Mixed case (uppercase < lowercase in ASCII).
	if strings.SortChars("AaBb") == "ABab" { pass = pass + 1 }

	// Duplicates preserved.
	if strings.SortChars("aabb") == "aabb" { pass = pass + 1 }
	if strings.SortChars("bbaa") == "aabb" { pass = pass + 1 }
	if strings.SortChars("zzzaaa") == "aaazzz" { pass = pass + 1 }

	// Word example.
	if strings.SortChars("hello") == "ehllo" { pass = pass + 1 }
	if strings.SortChars("world") == "dlorw" { pass = pass + 1 }

	// Anagram pairs share the same sorted form.
	if strings.SortChars("listen") == strings.SortChars("silent") { pass = pass + 1 }
	if strings.SortChars("evil") == strings.SortChars("vile") { pass = pass + 1 }
	if strings.SortChars("dusty") == strings.SortChars("study") { pass = pass + 1 }

	// Non-anagrams have different sorted forms.
	if strings.SortChars("abc") != strings.SortChars("abd") { pass = pass + 1 }

	// Includes spaces / punctuation.
	if strings.SortChars("a b") == " ab" { pass = pass + 1 }     // space (32) sorts before letters
	if strings.SortChars("!ab") == "!ab" { pass = pass + 1 }     // '!' (33) before letters

	// Idempotence.
	if strings.SortChars(strings.SortChars("zyxwvu")) == strings.SortChars("zyxwvu") { pass = pass + 1 }

	// Same-length result.
	if len(strings.SortChars("abcdef")) == 6 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
