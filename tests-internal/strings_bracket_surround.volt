package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Bracket — common bracket types.
	if strings.Bracket("item", "[", "]") == "[item]" { pass = pass + 1 }
	if strings.Bracket("arg", "(", ")") == "(arg)" { pass = pass + 1 }
	if strings.Bracket("obj", "{ ", " }") == "{ obj }" { pass = pass + 1 }
	if strings.Bracket("tag", "<", ">") == "<tag>" { pass = pass + 1 }

	// Bracket — empty s.
	if strings.Bracket("", "[", "]") == "[]" { pass = pass + 1 }

	// Bracket — empty brackets.
	if strings.Bracket("hello", "", "") == "hello" { pass = pass + 1 }

	// Bracket — asymmetric (CLI-style optional arg).
	if strings.Bracket("path", "--", "") == "--path" { pass = pass + 1 }
	if strings.Bracket("x", "[--", "]") == "[--x]" { pass = pass + 1 }

	// Multi-char brackets (HTML-style).
	if strings.Bracket("p", "</", ">") == "</p>" { pass = pass + 1 }
	if strings.Bracket("comment", "<!--", "-->") == "<!--comment-->" { pass = pass + 1 }

	// Surround — symmetric wrappers.
	if strings.Surround("bold", "*") == "*bold*" { pass = pass + 1 }
	if strings.Surround("hello", "\"") == "\"hello\"" { pass = pass + 1 }
	if strings.Surround("code", "`") == "`code`" { pass = pass + 1 }
	if strings.Surround("x", "==") == "==x==" { pass = pass + 1 }

	// Surround — empty s.
	if strings.Surround("", "*") == "**" { pass = pass + 1 }

	// Surround — empty wrap.
	if strings.Surround("hello", "") == "hello" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
