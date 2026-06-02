package main
import "log"
import "strings"

// Positive test: strings.OnlyDigits + strings.OnlyAlphanumeric.

fun main() int {
	var pass int = 0

	// OnlyDigits — basic.
	if strings.OnlyDigits("hello 123 world") == "123" { pass = pass + 1 }
	if strings.OnlyDigits("$1,234.50") == "123450" { pass = pass + 1 }
	if strings.OnlyDigits("(555) 867-5309") == "5558675309" { pass = pass + 1 }

	// OnlyDigits — only digits.
	if strings.OnlyDigits("12345") == "12345" { pass = pass + 1 }

	// OnlyDigits — no digits.
	if strings.OnlyDigits("hello world") == "" { pass = pass + 1 }
	if strings.OnlyDigits("") == "" { pass = pass + 1 }

	// OnlyDigits — punctuation only.
	if strings.OnlyDigits("...---...") == "" { pass = pass + 1 }

	// OnlyDigits — preserve leading zeros.
	if strings.OnlyDigits("0042") == "0042" { pass = pass + 1 }

	// OnlyAlphanumeric — basic.
	if strings.OnlyAlphanumeric("hello, world! 123") == "helloworld123" { pass = pass + 1 }
	if strings.OnlyAlphanumeric("abc-DEF-456") == "abcDEF456" { pass = pass + 1 }

	// OnlyAlphanumeric — no separators.
	if strings.OnlyAlphanumeric("abc123") == "abc123" { pass = pass + 1 }

	// OnlyAlphanumeric — all stripped.
	if strings.OnlyAlphanumeric("!@#$%") == "" { pass = pass + 1 }
	if strings.OnlyAlphanumeric("") == "" { pass = pass + 1 }

	// OnlyAlphanumeric — preserve case.
	if strings.OnlyAlphanumeric("Hi-There") == "HiThere" { pass = pass + 1 }

	// OnlyAlphanumeric — strips whitespace.
	if strings.OnlyAlphanumeric("a b c") == "abc" { pass = pass + 1 }
	if strings.OnlyAlphanumeric("a\tb\nc") == "abc" { pass = pass + 1 }

	// OnlyAlphanumeric — Unicode (multi-byte UTF-8) bytes drop because they're > 127.
	if strings.OnlyAlphanumeric("café") == "caf" { pass = pass + 1 }

	// OnlyDigits respects digit range bounds (0-9 only).
	if strings.OnlyDigits("a0z1b2") == "012" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
