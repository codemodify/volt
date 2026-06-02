package main
import "log"
import "strconv"

// Positive test: strconv.Unquote — inverse of strconv.Quote. Verifies
// Unquote(Quote(s)) == s for the same cases the Quote test covered,
// plus several direct Unquote roundtrips and error paths.

fun main() int {
	var pass int = 0

	var r string = ""
	var e error = nil

	// Round-trip Quote→Unquote.
	r, e = strconv.Unquote(strconv.Quote("hello"))
	if e == nil { pass = pass + 1 }
	if r == "hello" { pass = pass + 1 }

	r, e = strconv.Unquote(strconv.Quote("a\nb"))
	if r == "a\nb" { pass = pass + 1 }

	r, e = strconv.Unquote(strconv.Quote("a\\b"))
	if r == "a\\b" { pass = pass + 1 }

	r, e = strconv.Unquote(strconv.Quote("a\"b"))
	if r == "a\"b" { pass = pass + 1 }

	r, e = strconv.Unquote(strconv.Quote("\xff"))
	if r == "\xff" { pass = pass + 1 }

	r, e = strconv.Unquote(strconv.Quote("\x00"))
	if r == "\x00" { pass = pass + 1 }

	// Empty quoted string.
	r, e = strconv.Unquote("\"\"")
	if e == nil { pass = pass + 1 }
	if r == "" { pass = pass + 1 }

	// Direct Unquote.
	r, e = strconv.Unquote("\"hi\\tworld\"")
	if r == "hi\tworld" { pass = pass + 1 }

	r, e = strconv.Unquote("\"\\x7f\"")
	if r == "\x7f" { pass = pass + 1 }

	// Error: missing opening quote.
	r, e = strconv.Unquote("hello\"")
	if e != nil { pass = pass + 1 }

	// Error: too short.
	r, e = strconv.Unquote("x")
	if e != nil { pass = pass + 1 }

	// Error: dangling escape.
	r, e = strconv.Unquote("\"abc\\\"")
	if e != nil { pass = pass + 1 }

	// Error: unknown escape (\q).
	r, e = strconv.Unquote("\"\\q\"")
	if e != nil { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
