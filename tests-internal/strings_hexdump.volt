package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.Hexdump("") == "" { pass = pass + 1 }

	// FormatHexPad2 basics.
	if strings.FormatHexPad2(0) == "00" { pass = pass + 1 }
	if strings.FormatHexPad2(15) == "0f" { pass = pass + 1 }
	if strings.FormatHexPad2(255) == "ff" { pass = pass + 1 }
	if strings.FormatHexPad2(16) == "10" { pass = pass + 1 }
	if strings.FormatHexPad2(171) == "ab" { pass = pass + 1 }   // 0xab

	// FormatHexPad8 basics.
	if strings.FormatHexPad8(0) == "00000000" { pass = pass + 1 }
	if strings.FormatHexPad8(255) == "000000ff" { pass = pass + 1 }
	if strings.FormatHexPad8(4096) == "00001000" { pass = pass + 1 }

	// Single byte hexdump: just "h" (0x68).
	var hex1 string = strings.Hexdump("h")
	// Format: "00000000  68                                               |h|"
	// Verify starts with "00000000" and contains "68".
	if strings.HasPrefix(hex1, "00000000  68") { pass = pass + 1 }

	// Has the ASCII suffix.
	if strings.Contains(hex1, "|h|") { pass = pass + 1 }

	// "hello" (5 bytes) hexdump.
	var hex2 string = strings.Hexdump("hello")
	if strings.HasPrefix(hex2, "00000000  68 65 6c 6c 6f") { pass = pass + 1 }

	// ASCII suffix "|hello|".
	if strings.Contains(hex2, "|hello|") { pass = pass + 1 }

	// 16 bytes exactly: single row, no newline at end.
	var hex3 string = strings.Hexdump("0123456789abcdef")
	// Should be exactly one line.
	if !strings.Contains(hex3, "\n") { pass = pass + 1 }

	// 17 bytes: two rows, newline between.
	var hex4 string = strings.Hexdump("0123456789abcdefX")
	// Should have a newline.
	if strings.Contains(hex4, "\n") { pass = pass + 1 }
	// Second row offset should be "00000010".
	if strings.Contains(hex4, "00000010") { pass = pass + 1 }

	// Non-printable bytes shown as '.' in ASCII column.
	var hex5 string = strings.Hexdump("a\nb")
	// Has "|a.b|" suffix.
	if strings.Contains(hex5, "|a.b|") { pass = pass + 1 }

	// High-bit bytes shown as '.' in ASCII column.
	var hex6 string = strings.Hexdump("\xff")
	if strings.Contains(hex6, "ff") { pass = pass + 1 }
	if strings.Contains(hex6, "|.|") { pass = pass + 1 }

	// Use case: payload diagnosis dump.
	var packet string = "GET /\r\n"
	var dump string = strings.Hexdump(packet)
	if strings.HasPrefix(dump, "00000000  47 45 54 20 2f") { pass = pass + 1 }   // "GET /"

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
