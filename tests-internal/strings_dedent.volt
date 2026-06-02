package main
import "log"
import "strings"

// Positive test: strings.Dedent.

fun main() int {
	var pass int = 0

	// Two lines with 4-space common indent.
	var a string = "    hello\n    world"
	if strings.Dedent(a) == "hello\nworld" { pass = pass + 1 }

	// Three lines with mixed indent (common = 2).
	var b string = "  foo\n    bar\n  baz"
	if strings.Dedent(b) == "foo\n  bar\nbaz" { pass = pass + 1 }

	// No common indent.
	var c string = "foo\n  bar"
	if strings.Dedent(c) == "foo\n  bar" { pass = pass + 1 }

	// All-whitespace line in the middle doesn't constrain.
	var d string = "    one\n\n    two"
	if strings.Dedent(d) == "one\n\ntwo" { pass = pass + 1 }

	// All-whitespace line with spaces — doesn't constrain minWs, but
	// its leading-ws bytes are stripped up to that minimum (so a
	// 2-space blank line becomes empty after dedent of 4 spaces).
	var e string = "    one\n  \n    two"
	if strings.Dedent(e) == "one\n\ntwo" { pass = pass + 1 }

	// Single line.
	var f string = "    only"
	if strings.Dedent(f) == "only" { pass = pass + 1 }

	// Empty input.
	if strings.Dedent("") == "" { pass = pass + 1 }

	// Already dedented (no leading ws).
	var g string = "a\nb\nc"
	if strings.Dedent(g) == "a\nb\nc" { pass = pass + 1 }

	// Tab-indented.
	var h string = "\thi\n\tthere"
	if strings.Dedent(h) == "hi\nthere" { pass = pass + 1 }

	// Trailing newline preserved.
	var i string = "    one\n    two\n"
	if strings.Dedent(i) == "one\ntwo\n" { pass = pass + 1 }

	// Inverse of Indent — roundtrip.
	var src string = "foo\nbar"
	var indented string = strings.Indent(src, "    ")
	if strings.Dedent(indented) == src { pass = pass + 1 }

	// Just whitespace → unchanged (no non-blank line to constrain).
	if strings.Dedent("   \n  ") == "   \n  " { pass = pass + 1 }

	// Only blank lines plus one indented line.
	var j string = "\n\n    real"
	if strings.Dedent(j) == "\n\nreal" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
