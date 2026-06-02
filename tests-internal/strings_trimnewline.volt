package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// LF stripping.
	if strings.TrimNewline("hello\n") == "hello" { pass = pass + 1 }
	if strings.TrimNewline("\n") == "" { pass = pass + 1 }

	// CRLF stripping (both chars).
	if strings.TrimNewline("hello\r\n") == "hello" { pass = pass + 1 }
	if strings.TrimNewline("\r\n") == "" { pass = pass + 1 }

	// Lone CR stripping.
	if strings.TrimNewline("hello\r") == "hello" { pass = pass + 1 }
	if strings.TrimNewline("\r") == "" { pass = pass + 1 }

	// No-op when no trailing line ending.
	if strings.TrimNewline("hello") == "hello" { pass = pass + 1 }
	if strings.TrimNewline("") == "" { pass = pass + 1 }
	if strings.TrimNewline("a") == "a" { pass = pass + 1 }

	// Only ONE newline is removed (idempotent → strip-one-only).
	if strings.TrimNewline("hello\n\n") == "hello\n" { pass = pass + 1 }
	if strings.TrimNewline("hello\r\n\r\n") == "hello\r\n" { pass = pass + 1 }
	if strings.TrimNewline("hello\r\r") == "hello\r" { pass = pass + 1 }

	// Embedded newlines (only trailing affected).
	if strings.TrimNewline("line1\nline2\n") == "line1\nline2" { pass = pass + 1 }

	// CRLF preferred over LF on `\r\n` end (don't strip just the `\n`).
	if strings.TrimNewline("x\r\n") == "x" { pass = pass + 1 }

	// `\nx\r` keeps embedded `\n` and strips trailing `\r`.
	if strings.TrimNewline("\nx\r") == "\nx" { pass = pass + 1 }

	// Single space + LF → just space remains.
	if strings.TrimNewline(" \n") == " " { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
