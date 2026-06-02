package main
import "log"
import "strconv"

// Positive test: strconv.Quote returns a Go-syntax double-quoted
// string with escapes for control / quote / backslash bytes and
// \xNN for non-printable bytes.

fun main() int {
	var pass int = 0

	// Plain ASCII passes through with quotes added.
	if strconv.Quote("hello") == "\"hello\"" { pass = pass + 1 }

	// Empty string.
	if strconv.Quote("") == "\"\"" { pass = pass + 1 }

	// Newline → \n.
	if strconv.Quote("a\nb") == "\"a\\nb\"" { pass = pass + 1 }

	// Tab → \t.
	if strconv.Quote("a\tb") == "\"a\\tb\"" { pass = pass + 1 }

	// Backslash → \\.
	if strconv.Quote("a\\b") == "\"a\\\\b\"" { pass = pass + 1 }

	// Double-quote → \".
	if strconv.Quote("a\"b") == "\"a\\\"b\"" { pass = pass + 1 }

	// CR → \r.
	if strconv.Quote("a\rb") == "\"a\\rb\"" { pass = pass + 1 }

	// Non-printable byte → \xNN. \x01 = byte 1.
	if strconv.Quote("\x01") == "\"\\x01\"" { pass = pass + 1 }

	// High-bit byte → \xNN. \xff = byte 255.
	if strconv.Quote("\xff") == "\"\\xff\"" { pass = pass + 1 }

	// DEL (0x7f) → \x7f.
	if strconv.Quote("\x7f") == "\"\\x7f\"" { pass = pass + 1 }

	// Mixed printable + non-printable.
	if strconv.Quote("ok\n\x00bye") == "\"ok\\n\\x00bye\"" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
