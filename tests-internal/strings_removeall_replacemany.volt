package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// RemoveAll — basic.
	if strings.RemoveAll("hello world", new(2) []string { "l", "o" }) == "he wrd" { pass = pass + 1 }

	// RemoveAll — noise tokens.
	if strings.RemoveAll("<p>Hello <br>World</p>", new(2) []string { "<br>", "<p>" }) == "Hello World</p>" { pass = pass + 1 }

	// RemoveAll — none of the subs found.
	if strings.RemoveAll("abc", new(2) []string { "x", "y" }) == "abc" { pass = pass + 1 }

	// RemoveAll — empty subs.
	if strings.RemoveAll("abc", new(0) []string {}) == "abc" { pass = pass + 1 }

	// RemoveAll — empty sub strings in slice are skipped.
	if strings.RemoveAll("abc", new(2) []string { "", "b" }) == "ac" { pass = pass + 1 }

	// RemoveAll — empty s.
	if strings.RemoveAll("", new(1) []string { "a" }) == "" { pass = pass + 1 }

	// RemoveAll — strip multiple punctuations.
	if strings.RemoveAll("a,b;c.d", new(3) []string { ",", ";", "." }) == "abcd" { pass = pass + 1 }

	// RemoveAll — order matters when substrings overlap.
	// "aabb": removing "aa" then "bb" → "" — but removing "a" then "ab" can leave differently.
	if strings.RemoveAll("aabb", new(2) []string { "aa", "bb" }) == "" { pass = pass + 1 }

	// ReplaceMany — basic.
	if strings.ReplaceMany("hello world", new(4) []string { "hello", "HI", "world", "EARTH" }) == "HI EARTH" { pass = pass + 1 }

	// ReplaceMany — empty pairs.
	if strings.ReplaceMany("foo", new(0) []string {}) == "foo" { pass = pass + 1 }

	// ReplaceMany — odd-length input ignores trailing unmatched.
	if strings.ReplaceMany("abc", new(3) []string { "a", "X", "trailing" }) == "Xbc" { pass = pass + 1 }

	// ReplaceMany — chained substitution.
	if strings.ReplaceMany("a-b-c", new(4) []string { "-", "_", "_", "/" }) == "a/b/c" { pass = pass + 1 }
	// First pass: "a_b_c"; second pass: "a/b/c"

	// ReplaceMany — replace with empty (effectively RemoveAll).
	if strings.ReplaceMany("hello", new(2) []string { "l", "" }) == "heo" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
