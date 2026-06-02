package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Zero.
	var b1 *strings.Builder = strings.NewBuilder()
	b1.WriteInt(0)
	if b1.String() == "0" { pass = pass + 1 }
	if b1.Len() == 1 { pass = pass + 1 }

	// Positive.
	var b2 *strings.Builder = strings.NewBuilder()
	b2.WriteInt(42)
	if b2.String() == "42" { pass = pass + 1 }

	// Multi-digit.
	var b3 *strings.Builder = strings.NewBuilder()
	b3.WriteInt(1234567)
	if b3.String() == "1234567" { pass = pass + 1 }
	if b3.Len() == 7 { pass = pass + 1 }

	// Negative.
	var b4 *strings.Builder = strings.NewBuilder()
	b4.WriteInt(-99)
	if b4.String() == "-99" { pass = pass + 1 }

	// Large.
	var b5 *strings.Builder = strings.NewBuilder()
	b5.WriteInt(1000000000)
	if b5.String() == "1000000000" { pass = pass + 1 }

	// Mixed with WriteString.
	var b6 *strings.Builder = strings.NewBuilder()
	b6.WriteString("count=")
	b6.WriteInt(42)
	if b6.String() == "count=42" { pass = pass + 1 }
	if b6.Len() == 8 { pass = pass + 1 }

	// Log-line style accumulation.
	var b7 *strings.Builder = strings.NewBuilder()
	b7.WriteString("[")
	b7.WriteInt(2026)
	b7.WriteString("-")
	b7.WriteInt(5)
	b7.WriteString("-")
	b7.WriteInt(28)
	b7.WriteString("] event ")
	b7.WriteInt(1)
	if b7.String() == "[2026-5-28] event 1" { pass = pass + 1 }

	// After Reset.
	var b8 *strings.Builder = strings.NewBuilder()
	b8.WriteString("garbage")
	b8.Reset()
	b8.WriteInt(7)
	if b8.String() == "7" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
