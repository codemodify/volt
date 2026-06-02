package main
import "log"
import "bufio"

fun discard(s string) (int, error) {
	ret len(s), nil
}

fun main() int {
	var pass int = 0

	// WriteByte.
	var b1 *bufio.Buffer = bufio.New(discard)
	b1.WriteByte(65)    // 'A'
	b1.WriteByte(66)    // 'B'
	if b1.String() == "AB" { pass = pass + 1 }
	if b1.Len() == 2 { pass = pass + 1 }

	// WriteInt.
	var b2 *bufio.Buffer = bufio.New(discard)
	b2.WriteInt(42)
	if b2.String() == "42" { pass = pass + 1 }
	b2.WriteInt(-99)
	if b2.String() == "42-99" { pass = pass + 1 }
	b2.WriteInt(0)
	if b2.String() == "42-990" { pass = pass + 1 }

	// WriteBool.
	var b3 *bufio.Buffer = bufio.New(discard)
	b3.WriteBool(true)
	if b3.String() == "true" { pass = pass + 1 }
	b3.WriteBool(false)
	if b3.String() == "truefalse" { pass = pass + 1 }

	// Combined log-line.
	var b4 *bufio.Buffer = bufio.New(discard)
	b4.WriteByte(91)    // '['
	b4.WriteInt(2026)
	b4.WriteByte(93)    // ']'
	b4.WriteString(" enabled=")
	b4.WriteBool(true)
	b4.WriteString(" count=")
	b4.WriteInt(7)
	if b4.String() == "[2026] enabled=true count=7" { pass = pass + 1 }

	// Flush returns the right byte count.
	var n int = 0
	var err error = nil
	n, err = b4.Flush()
	if err == nil { pass = pass + 1 }
	if n == 27 { pass = pass + 1 }
	if b4.Len() == 0 { pass = pass + 1 }

	// Reset works after combined writes.
	var b5 *bufio.Buffer = bufio.New(discard)
	b5.WriteInt(123)
	b5.WriteBool(false)
	b5.Reset()
	if b5.Len() == 0 { pass = pass + 1 }
	b5.WriteByte(120)
	if b5.String() == "x" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
