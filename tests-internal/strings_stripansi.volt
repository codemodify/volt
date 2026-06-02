package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// StripAnsi — no ANSI is identity.
	if strings.StripAnsi("hello") == "hello" { pass = pass + 1 }
	if strings.StripAnsi("") == "" { pass = pass + 1 }

	// StripAnsi — simple SGR color sequences.
	if strings.StripAnsi("\x1b[31mred\x1b[0m") == "red" { pass = pass + 1 }
	if strings.StripAnsi("\x1b[1mbold\x1b[0m") == "bold" { pass = pass + 1 }
	if strings.StripAnsi("\x1b[38;5;208morange\x1b[0m") == "orange" { pass = pass + 1 }

	// StripAnsi — mixed text and ANSI.
	if strings.StripAnsi("before \x1b[32mgreen\x1b[0m after") == "before green after" { pass = pass + 1 }
	if strings.StripAnsi("a\x1b[1mb\x1b[0mc") == "abc" { pass = pass + 1 }

	// StripAnsi — multiple consecutive sequences.
	if strings.StripAnsi("\x1b[1m\x1b[31mx") == "x" { pass = pass + 1 }
	if strings.StripAnsi("\x1b[0m\x1b[0m") == "" { pass = pass + 1 }

	// StripAnsi — CSI sequences with non-`m` final byte (cursor move,
	// clear line, etc.) are also stripped.
	if strings.StripAnsi("\x1b[2J") == "" { pass = pass + 1 }              // clear screen
	if strings.StripAnsi("\x1b[10;5H") == "" { pass = pass + 1 }           // cursor position
	if strings.StripAnsi("\x1b[K end") == " end" { pass = pass + 1 }       // clear-to-EOL

	// StripAnsi — non-CSI ESC sequence (ESC + single byte) drops both.
	if strings.StripAnsi("a\x1b=b") == "ab" { pass = pass + 1 }

	// StripAnsi — lone ESC at end is dropped.
	if strings.StripAnsi("hi\x1b") == "hi" { pass = pass + 1 }

	// StripAnsi — preserves newlines / tabs / other control chars.
	if strings.StripAnsi("line1\n\x1b[32mline2\x1b[0m\nline3") == "line1\nline2\nline3" { pass = pass + 1 }
	if strings.StripAnsi("a\tb") == "a\tb" { pass = pass + 1 }

	// StripAnsi — back-to-back ANSI then text.
	if strings.StripAnsi("\x1b[1m\x1b[4mboth") == "both" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
