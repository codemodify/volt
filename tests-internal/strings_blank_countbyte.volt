package main
import "log"
import "strings"

// Positive test: strings.IsBlank + strings.CountByte.

fun main() int {
	var pass int = 0

	// IsBlank — empty.
	if strings.IsBlank("") { pass = pass + 1 }
	// Single space.
	if strings.IsBlank(" ") { pass = pass + 1 }
	// Multiple whitespace bytes.
	if strings.IsBlank(" \t\n\r") { pass = pass + 1 }
	// Whitespace followed by non-whitespace.
	if !strings.IsBlank("  x  ") { pass = pass + 1 }
	// Single letter.
	if !strings.IsBlank("a") { pass = pass + 1 }
	// Whitespace surrounded by tabs.
	if strings.IsBlank("\t\t\t") { pass = pass + 1 }
	// Newlines only.
	if strings.IsBlank("\n\n\n") { pass = pass + 1 }
	// Trailing whitespace.
	if !strings.IsBlank("hello ") { pass = pass + 1 }

	// CountByte — single byte present.
	if strings.CountByte("hello", 108) == 2 { pass = pass + 1 }   // two 'l'
	// Byte not present.
	if strings.CountByte("hello", 120) == 0 { pass = pass + 1 }   // no 'x'
	// Empty string.
	if strings.CountByte("", 32) == 0 { pass = pass + 1 }
	// All same.
	if strings.CountByte("xxxxx", 120) == 5 { pass = pass + 1 }
	// Count spaces.
	if strings.CountByte("a b c d", 32) == 3 { pass = pass + 1 }
	// Count newlines.
	if strings.CountByte("line1\nline2\nline3", 10) == 2 { pass = pass + 1 }
	// Count zero byte.
	if strings.CountByte("\x00abc\x00", 0) == 2 { pass = pass + 1 }
	// High-bit byte.
	if strings.CountByte("a\xffb\xffc\xff", 255) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
