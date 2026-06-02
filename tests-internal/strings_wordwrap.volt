package main
import "log"
import "strings"

// Positive test: strings.WordWrap.

fun main() int {
	var pass int = 0

	// Short text fits on one line.
	if strings.WordWrap("hi there", 80) == "hi there" { pass = pass + 1 }

	// Wrap at boundary.
	if strings.WordWrap("hi there world", 10) == "hi there\nworld" { pass = pass + 1 }

	// Multiple wraps.
	var r1 string = strings.WordWrap("one two three four five", 9)
	if r1 == "one two\nthree\nfour five" { pass = pass + 1 }

	// Exactly equal to width — fits without wrap.
	if strings.WordWrap("ab cd", 5) == "ab cd" { pass = pass + 1 }
	// One byte over width — wraps.
	if strings.WordWrap("ab cd", 4) == "ab\ncd" { pass = pass + 1 }

	// Single long word that exceeds width — placed alone on a line.
	if strings.WordWrap("supercalifragilistic", 5) == "supercalifragilistic" { pass = pass + 1 }

	// Mix of short + long.
	var r2 string = strings.WordWrap("a supercalifragilistic b", 5)
	if r2 == "a\nsupercalifragilistic\nb" { pass = pass + 1 }

	// Empty / whitespace-only.
	if strings.WordWrap("", 10) == "" { pass = pass + 1 }
	if strings.WordWrap("   ", 10) == "" { pass = pass + 1 }
	if strings.WordWrap("\t\n", 10) == "" { pass = pass + 1 }

	// Width 0 → unchanged.
	if strings.WordWrap("foo bar baz", 0) == "foo bar baz" { pass = pass + 1 }

	// Width negative → unchanged.
	if strings.WordWrap("foo bar baz", -1) == "foo bar baz" { pass = pass + 1 }

	// Multiple spaces collapse via Fields.
	if strings.WordWrap("a    b   c", 80) == "a b c" { pass = pass + 1 }

	// Width fits two short words.
	if strings.WordWrap("aaa bb cc d e f g h i j", 6) == "aaa bb\ncc d e\nf g h\ni j" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
