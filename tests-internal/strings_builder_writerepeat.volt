package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Basic count.
	var b1 *strings.Builder = strings.NewBuilder()
	b1.WriteRepeat(32, 5)
	if b1.Len() == 5 { pass = pass + 1 }
	if b1.String() == "     " { pass = pass + 1 }

	// Count <= 0 is a no-op.
	var b2 *strings.Builder = strings.NewBuilder()
	b2.WriteRepeat(32, 0)
	if b2.Len() == 0 { pass = pass + 1 }
	b2.WriteRepeat(32, -3)
	if b2.Len() == 0 { pass = pass + 1 }

	// Mixed with WriteString.
	var b3 *strings.Builder = strings.NewBuilder()
	b3.WriteString("key:")
	b3.WriteRepeat(32, 3)
	b3.WriteString("value")
	if b3.String() == "key:   value" { pass = pass + 1 }
	if b3.Len() == 12 { pass = pass + 1 }

	// Framing pattern.
	var b4 *strings.Builder = strings.NewBuilder()
	b4.WriteRepeat(45, 5)
	b4.WriteString(" header ")
	b4.WriteRepeat(45, 5)
	if b4.String() == "----- header -----" { pass = pass + 1 }

	// Larger fill.
	var b5 *strings.Builder = strings.NewBuilder()
	b5.WriteRepeat(120, 100)
	if b5.Len() == 100 { pass = pass + 1 }
	var s string = b5.String()
	if len(s) == 100 { pass = pass + 1 }
	if s[0] == 120 { pass = pass + 1 }
	if s[99] == 120 { pass = pass + 1 }
	if s[50] == 120 { pass = pass + 1 }

	// Count of 1.
	var b6 *strings.Builder = strings.NewBuilder()
	b6.WriteRepeat(65, 1)
	if b6.String() == "A" { pass = pass + 1 }

	// After Reset.
	var b7 *strings.Builder = strings.NewBuilder()
	b7.WriteString("garbage")
	b7.Reset()
	b7.WriteRepeat(46, 4)
	if b7.String() == "...." { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
