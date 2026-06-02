package main
import "log"
import "bytes"

// Positive test: bytes.Builder.WriteBytes + Builder.Bytes.

fun main() int {
	var pass int = 0

	// WriteBytes append + String roundtrip.
	var b *bytes.Builder = bytes.NewBuilder()
	b.WriteString("hi ")
	var data []byte = new(5) []byte{119, 111, 114, 108, 100}   // "world"
	b.WriteBytes(data)
	if b.Len() == 8 { pass = pass + 1 }
	if b.String() == "hi world" { pass = pass + 1 }

	// Bytes() returns a fresh slice with the accumulated bytes.
	var b2 *bytes.Builder = bytes.NewBuilder()
	b2.WriteByte(65)   // 'A'
	b2.WriteByte(66)   // 'B'
	b2.WriteByte(67)   // 'C'
	var out []byte = b2.Bytes()
	if len(out) == 3 { pass = pass + 1 }
	if out[0] == 65 { pass = pass + 1 }
	if out[1] == 66 { pass = pass + 1 }
	if out[2] == 67 { pass = pass + 1 }

	// Builder is still usable after Bytes() (separate buffer).
	b2.WriteByte(68)
	if b2.Len() == 4 { pass = pass + 1 }

	// WriteBytes empty input.
	var b3 *bytes.Builder = bytes.NewBuilder()
	var empty []byte = new(0) []byte{}
	b3.WriteBytes(empty)
	if b3.Len() == 0 { pass = pass + 1 }

	// Bytes() on empty Builder → empty slice.
	var b4 *bytes.Builder = bytes.NewBuilder()
	var bs []byte = b4.Bytes()
	if len(bs) == 0 { pass = pass + 1 }

	log.Println("pass=%d s=%s", pass, b.String())
	if pass == 9 { ret 42 }
	ret 0
}
