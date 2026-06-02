package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.IsAsciiPrintable("") { pass = pass + 1 }

	// All printable.
	if strings.IsAsciiPrintable("hello") { pass = pass + 1 }
	if strings.IsAsciiPrintable("Hello, World! 123") { pass = pass + 1 }
	if strings.IsAsciiPrintable("abcdefghijklmnopqrstuvwxyz") { pass = pass + 1 }
	if strings.IsAsciiPrintable("0123456789") { pass = pass + 1 }
	if strings.IsAsciiPrintable("!\"#$%&'()*+,-./:;<=>?@[\\]^_`{|}~") { pass = pass + 1 }

	// Boundary — space (32) and ~ (126).
	if strings.IsAsciiPrintable(" ") { pass = pass + 1 }
	if strings.IsAsciiPrintable("~") { pass = pass + 1 }

	// Boundary — fail at 0x1F (just below space) and 0x7F (DEL).
	if !strings.IsAsciiPrintable("\x1f") { pass = pass + 1 }
	if !strings.IsAsciiPrintable("\x7f") { pass = pass + 1 }

	// Control chars fail.
	if !strings.IsAsciiPrintable("\n") { pass = pass + 1 }
	if !strings.IsAsciiPrintable("\t") { pass = pass + 1 }
	if !strings.IsAsciiPrintable("\x00") { pass = pass + 1 }
	if !strings.IsAsciiPrintable("a\nb") { pass = pass + 1 }

	// High-bit / non-ASCII fail.
	if !strings.IsAsciiPrintable("a\xc3\xa9b") { pass = pass + 1 }   // é
	if !strings.IsAsciiPrintable("\xff") { pass = pass + 1 }

	// Single space → true (32 is printable per the standard).
	if strings.IsAsciiPrintable(" ") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
