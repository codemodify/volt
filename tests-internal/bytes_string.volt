package main
import "log"
import "bytes"

// Positive test: bytes.String — convert []byte to immutable string
// via the existing syscall.BytesToString intrinsic.

fun main() int {
	var pass int = 0

	// Standard conversion.
	var b1 []byte = new(5) []byte{72, 101, 108, 108, 111}    // "Hello"
	var s1 string = bytes.String(b1)
	if s1 == "Hello" { pass = pass + 1 }
	if len(s1) == 5 { pass = pass + 1 }

	// Empty slice.
	var b2 []byte = new(0) []byte{}
	var s2 string = bytes.String(b2)
	if s2 == "" { pass = pass + 1 }
	if len(s2) == 0 { pass = pass + 1 }

	// Non-ASCII bytes (0xff, 0x00 inside).
	var b3 []byte = new(3) []byte{255, 0, 65}
	var s3 string = bytes.String(b3)
	if len(s3) == 3 { pass = pass + 1 }
	if s3[2] == 65 { pass = pass + 1 }

	// Roundtrip: convert back via bytes.Builder.WriteString → Bytes.
	var bld *bytes.Builder = bytes.NewBuilder()
	bld.WriteString(bytes.String(new(3) []byte{97, 98, 99}))   // "abc"
	if bld.String() == "abc" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 7 { ret 42 }
	ret 0
}
