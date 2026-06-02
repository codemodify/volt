package main
import "log"
import "strings"

// Positive test: strings.ReplaceFirst + strings.ReplaceN.

fun main() int {
	var pass int = 0

	// ReplaceFirst — basic.
	if strings.ReplaceFirst("foo bar foo baz", "foo", "X") == "X bar foo baz" { pass = pass + 1 }
	// ReplaceFirst — no match.
	if strings.ReplaceFirst("hello world", "zzz", "X") == "hello world" { pass = pass + 1 }
	// ReplaceFirst — match at start.
	if strings.ReplaceFirst("aabaa", "a", "X") == "Xabaa" { pass = pass + 1 }
	// ReplaceFirst — match at end.
	if strings.ReplaceFirst("xabc", "c", "Z") == "xabZ" { pass = pass + 1 }
	// ReplaceFirst — old equals s.
	if strings.ReplaceFirst("hello", "hello", "world") == "world" { pass = pass + 1 }
	// ReplaceFirst — empty s.
	if strings.ReplaceFirst("", "x", "y") == "" { pass = pass + 1 }
	// ReplaceFirst — empty old → unchanged.
	if strings.ReplaceFirst("hello", "", "X") == "hello" { pass = pass + 1 }
	// ReplaceFirst — empty repl (deletion).
	if strings.ReplaceFirst("foo bar foo", "foo ", "") == "bar foo" { pass = pass + 1 }
	// ReplaceFirst — longer repl.
	if strings.ReplaceFirst("ab", "a", "XYZ") == "XYZb" { pass = pass + 1 }

	// ReplaceN — n=2.
	if strings.ReplaceN("a-a-a-a", "a", "X", 2) == "X-X-a-a" { pass = pass + 1 }
	// ReplaceN — n=0 returns unchanged.
	if strings.ReplaceN("a-a-a", "a", "X", 0) == "a-a-a" { pass = pass + 1 }
	// ReplaceN — n=-1 replaces all (matches Go's strings.Replace).
	if strings.ReplaceN("a-a-a", "a", "X", -1) == "X-X-X" { pass = pass + 1 }
	// ReplaceN — n=1 equals ReplaceFirst.
	if strings.ReplaceN("foo foo foo", "foo", "X", 1) == "X foo foo" { pass = pass + 1 }
	// ReplaceN — n larger than occurrences.
	if strings.ReplaceN("a-a", "a", "X", 5) == "X-X" { pass = pass + 1 }
	// ReplaceN — empty old.
	if strings.ReplaceN("hello", "", "X", 3) == "hello" { pass = pass + 1 }
	// ReplaceN — n=3 mid-string.
	if strings.ReplaceN("xxxxxxx", "x", "yy", 3) == "yyyyyyxxxx" { pass = pass + 1 }
	// ReplaceN — overlapping potential (each match consumed).
	if strings.ReplaceN("aaaa", "aa", "b", 2) == "bb" { pass = pass + 1 }
	// ReplaceN — no match.
	if strings.ReplaceN("hello", "zzz", "X", 3) == "hello" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
