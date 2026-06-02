package main
import "log"
import "strings"

// Positive test: strings.Title.

fun main() int {
	var pass int = 0

	// Basic word.
	if strings.Title("hello") == "Hello" { pass = pass + 1 }
	// Two words.
	if strings.Title("hello world") == "Hello World" { pass = pass + 1 }
	// Already titled.
	if strings.Title("Hello World") == "Hello World" { pass = pass + 1 }
	// Mixed case — only first letter changes; middle of word preserved.
	if strings.Title("hELLO wORLD") == "HELLO WORLD" { pass = pass + 1 }
	// Multiple spaces in a row.
	if strings.Title("foo  bar") == "Foo  Bar" { pass = pass + 1 }
	// Tab + newline separators.
	if strings.Title("a\tb\nc") == "A\tB\nC" { pass = pass + 1 }
	// Carriage return separator.
	if strings.Title("x\ry") == "X\rY" { pass = pass + 1 }
	// Leading whitespace then word.
	if strings.Title(" hi") == " Hi" { pass = pass + 1 }
	// Trailing whitespace preserved.
	if strings.Title("hi ") == "Hi " { pass = pass + 1 }
	// Empty.
	if strings.Title("") == "" { pass = pass + 1 }
	// Single char letter.
	if strings.Title("z") == "Z" { pass = pass + 1 }
	// Single char already upper.
	if strings.Title("Z") == "Z" { pass = pass + 1 }
	// Non-letter prefix doesn't crash (digit at word start stays digit).
	if strings.Title("1st place") == "1st Place" { pass = pass + 1 }
	// Punctuation in word — Title only touches the first char after whitespace.
	if strings.Title("foo-bar baz") == "Foo-bar Baz" { pass = pass + 1 }
	// All whitespace.
	if strings.Title("   ") == "   " { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
