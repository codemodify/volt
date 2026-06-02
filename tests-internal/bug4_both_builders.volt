package main
import "log"
import "bytes"
import "strings"

// BUG.4 validation: both bytes.Builder and strings.Builder define
// WriteByte / WriteString / String / Reset / Len. Method dispatch
// must use the receiver's package qualifier so each call lands on
// the correct concrete method, even though the bare type name
// "Builder" is shared.

fun main() int {
	var pass int = 0

	// bytes.Builder — writes 'A' 'B' 'C' (65 66 67).
	var bb *bytes.Builder = bytes.NewBuilder()
	bb.WriteByte(65)
	bb.WriteByte(66)
	bb.WriteByte(67)
	if bb.Len() == 3 { pass = pass + 1 }
	var s1 string = bb.String()
	if s1 == "ABC" { pass = pass + 1 }

	// strings.Builder — writes 'X' 'Y' 'Z' (88 89 90).
	var sb *strings.Builder = strings.NewBuilder()
	sb.WriteByte(88)
	sb.WriteByte(89)
	sb.WriteByte(90)
	if sb.Len() == 3 { pass = pass + 1 }
	var s2 string = sb.String()
	if s2 == "XYZ" { pass = pass + 1 }

	// WriteString on both — must hit each type's own implementation.
	var bb2 *bytes.Builder = bytes.NewBuilder()
	bb2.WriteString("hello ")
	bb2.WriteString("world")
	if bb2.String() == "hello world" { pass = pass + 1 }

	var sb2 *strings.Builder = strings.NewBuilder()
	sb2.WriteString("foo ")
	sb2.WriteString("bar")
	if sb2.String() == "foo bar" { pass = pass + 1 }

	// Reset on both.
	bb.Reset()
	if bb.Len() == 0 { pass = pass + 1 }
	sb.Reset()
	if sb.Len() == 0 { pass = pass + 1 }

	// Interleave — both alive at once.
	var bb3 *bytes.Builder = bytes.NewBuilder()
	var sb3 *strings.Builder = strings.NewBuilder()
	bb3.WriteByte(97)         // 'a'
	sb3.WriteByte(48)         // '0'
	bb3.WriteByte(98)         // 'b'
	sb3.WriteByte(49)         // '1'
	if bb3.String() == "ab" { pass = pass + 1 }
	if sb3.String() == "01" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
