package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty / whitespace-only → "".
	if strings.ReverseWords("") == "" { pass = pass + 1 }
	if strings.ReverseWords("   ") == "" { pass = pass + 1 }
	if strings.ReverseWords("\t\n") == "" { pass = pass + 1 }

	// Single word stays the same.
	if strings.ReverseWords("solo") == "solo" { pass = pass + 1 }

	// Two words.
	if strings.ReverseWords("hello world") == "world hello" { pass = pass + 1 }

	// Three words.
	if strings.ReverseWords("a b c") == "c b a" { pass = pass + 1 }
	if strings.ReverseWords("the quick brown") == "brown quick the" { pass = pass + 1 }

	// Whitespace shape collapses to single-space.
	if strings.ReverseWords("  hello   world  ") == "world hello" { pass = pass + 1 }
	if strings.ReverseWords("\tfoo\nbar") == "bar foo" { pass = pass + 1 }

	// 4-word.
	if strings.ReverseWords("one two three four") == "four three two one" { pass = pass + 1 }

	// Names use case ("first last" → "last first").
	if strings.ReverseWords("Alice Smith") == "Smith Alice" { pass = pass + 1 }

	// Double-reverse approximates identity (modulo whitespace
	// normalization) when input is already single-space-separated.
	var orig string = "rust go zig c"
	if strings.ReverseWords(strings.ReverseWords(orig)) == orig { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
