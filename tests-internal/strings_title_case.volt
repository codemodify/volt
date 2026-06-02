package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Basic: lowercase to title.
	if strings.TitleCase("hello world") == "Hello World" { pass = pass + 1 }

	// Already title.
	if strings.TitleCase("Hello World") == "Hello World" { pass = pass + 1 }

	// All caps → title.
	if strings.TitleCase("HELLO WORLD") == "Hello World" { pass = pass + 1 }

	// Mixed.
	if strings.TitleCase("hELlO wOrLd") == "Hello World" { pass = pass + 1 }

	// Empty.
	if strings.TitleCase("") == "" { pass = pass + 1 }

	// Single word.
	if strings.TitleCase("foo") == "Foo" { pass = pass + 1 }
	if strings.TitleCase("FOO") == "Foo" { pass = pass + 1 }

	// Multiple spaces preserved.
	if strings.TitleCase("a  b") == "A  B" { pass = pass + 1 }

	// Tab-separated.
	if strings.TitleCase("foo\tbar") == "Foo\tBar" { pass = pass + 1 }

	// Newline-separated.
	if strings.TitleCase("foo\nbar") == "Foo\nBar" { pass = pass + 1 }

	// Punctuation passes through unchanged (only letters affected).
	if strings.TitleCase("hello, world!") == "Hello, World!" { pass = pass + 1 }

	// Numbers and symbols.
	if strings.TitleCase("abc 123 def") == "Abc 123 Def" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
