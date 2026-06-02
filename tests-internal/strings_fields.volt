package main
import "log"
import "strings"

// Positive test: strings.Fields(s) splits on runs of whitespace
// (space / tab / newline / CR / VT / FF), collapsing adjacent
// whitespace. Empty or all-whitespace input returns an empty slice.

fun main() int {
	var pass int = 0

	var a []string = strings.Fields("hello world")
	if len(a) == 2 { pass = pass + 1 }
	if a[0] == "hello" { pass = pass + 1 }
	if a[1] == "world" { pass = pass + 1 }

	// Adjacent whitespace runs collapse.
	var b []string = strings.Fields("  foo   bar  baz  ")
	if len(b) == 3 { pass = pass + 1 }
	if b[0] == "foo" { pass = pass + 1 }
	if b[1] == "bar" { pass = pass + 1 }
	if b[2] == "baz" { pass = pass + 1 }

	// Mixed whitespace bytes.
	var c []string = strings.Fields("a\tb\nc\rd")
	if len(c) == 4 { pass = pass + 1 }
	if c[0] == "a" { pass = pass + 1 }
	if c[3] == "d" { pass = pass + 1 }

	// Empty input.
	var d []string = strings.Fields("")
	if len(d) == 0 { pass = pass + 1 }

	// All-whitespace input.
	var e []string = strings.Fields("   \t\n  ")
	if len(e) == 0 { pass = pass + 1 }

	// Single token, no whitespace.
	var f []string = strings.Fields("solo")
	if len(f) == 1 { pass = pass + 1 }
	if f[0] == "solo" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
