package main
import "log"
import "bytes"
import "strings"

fun strBytes(s string) []byte {
	var n int = len(s)
	var out []byte = new(n) []byte {}
	for i := 0; i < n; i++ { out[i] = s[i] }
	ret out
}

fun main() int {
	var pass int = 0

	// Empty.
	var e []byte = strBytes("")
	if bytes.Hexdump(e) == "" { pass = pass + 1 }

	// Single byte.
	var s1 []byte = strBytes("h")
	var hex1 string = bytes.Hexdump(s1)
	if strings.HasPrefix(hex1, "00000000  68") { pass = pass + 1 }
	if strings.Contains(hex1, "|h|") { pass = pass + 1 }

	// "hello" — 5 bytes.
	var s2 []byte = strBytes("hello")
	var hex2 string = bytes.Hexdump(s2)
	if strings.HasPrefix(hex2, "00000000  68 65 6c 6c 6f") { pass = pass + 1 }
	if strings.Contains(hex2, "|hello|") { pass = pass + 1 }

	// 16 bytes exactly.
	var s3 []byte = strBytes("0123456789abcdef")
	var hex3 string = bytes.Hexdump(s3)
	if !strings.Contains(hex3, "\n") { pass = pass + 1 }

	// 17 bytes → two rows.
	var s4 []byte = strBytes("0123456789abcdefX")
	var hex4 string = bytes.Hexdump(s4)
	if strings.Contains(hex4, "\n") { pass = pass + 1 }
	if strings.Contains(hex4, "00000010") { pass = pass + 1 }

	// Non-printable bytes.
	var s5 []byte = strBytes("a\nb")
	var hex5 string = bytes.Hexdump(s5)
	if strings.Contains(hex5, "|a.b|") { pass = pass + 1 }

	// High-bit bytes.
	var s6 []byte = new(1) []byte { 255 }
	var hex6 string = bytes.Hexdump(s6)
	if strings.Contains(hex6, "ff") { pass = pass + 1 }
	if strings.Contains(hex6, "|.|") { pass = pass + 1 }

	// Cross-equivalence with strings.Hexdump on identical content.
	var s7 []byte = strBytes("GET /\r\n")
	var hexB string = bytes.Hexdump(s7)
	var hexS string = strings.Hexdump("GET /\r\n")
	if hexB == hexS { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
