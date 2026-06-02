package main
import "log"
import "strings"
import "bytes"

// Positive test: strings.IsValidIdentifier + bytes.Reverse.

fun main() int {
	var pass int = 0

	// IsValidIdentifier — valid.
	if strings.IsValidIdentifier("foo") { pass = pass + 1 }
	if strings.IsValidIdentifier("Foo") { pass = pass + 1 }
	if strings.IsValidIdentifier("_") { pass = pass + 1 }
	if strings.IsValidIdentifier("_x") { pass = pass + 1 }
	if strings.IsValidIdentifier("camelCase") { pass = pass + 1 }
	if strings.IsValidIdentifier("snake_case") { pass = pass + 1 }
	if strings.IsValidIdentifier("HTTP200") { pass = pass + 1 }
	if strings.IsValidIdentifier("a1") { pass = pass + 1 }
	if strings.IsValidIdentifier("x123_456") { pass = pass + 1 }

	// IsValidIdentifier — invalid.
	if !strings.IsValidIdentifier("") { pass = pass + 1 }
	if !strings.IsValidIdentifier("1foo") { pass = pass + 1 }
	if !strings.IsValidIdentifier("foo bar") { pass = pass + 1 }
	if !strings.IsValidIdentifier("foo-bar") { pass = pass + 1 }
	if !strings.IsValidIdentifier("foo.bar") { pass = pass + 1 }
	if !strings.IsValidIdentifier("foo!") { pass = pass + 1 }
	if !strings.IsValidIdentifier(" foo") { pass = pass + 1 }
	if !strings.IsValidIdentifier("foo ") { pass = pass + 1 }

	// bytes.Reverse — basic.
	var a []byte = new(5) []byte{65, 66, 67, 68, 69}    // A B C D E
	var ra []byte = bytes.Reverse(a)
	if len(ra) == 5 { pass = pass + 1 }
	if ra[0] == 69 { pass = pass + 1 }
	if ra[1] == 68 { pass = pass + 1 }
	if ra[4] == 65 { pass = pass + 1 }

	// bytes.Reverse — single element.
	var s []byte = new(1) []byte{42}
	var rs []byte = bytes.Reverse(s)
	if len(rs) == 1 { pass = pass + 1 }
	if rs[0] == 42 { pass = pass + 1 }

	// bytes.Reverse — empty.
	var e []byte = new(0) []byte{}
	if len(bytes.Reverse(e)) == 0 { pass = pass + 1 }

	// bytes.Reverse — palindrome stays the same.
	var p []byte = new(3) []byte{1, 2, 1}
	var rp []byte = bytes.Reverse(p)
	if rp[0] == 1 { pass = pass + 1 }
	if rp[1] == 2 { pass = pass + 1 }
	if rp[2] == 1 { pass = pass + 1 }

	// Roundtrip — Reverse(Reverse(s)) == s.
	var b []byte = new(4) []byte{10, 20, 30, 40}
	var rb []byte = bytes.Reverse(b)
	var rrb []byte = bytes.Reverse(rb)
	if rrb[0] == 10 { pass = pass + 1 }
	if rrb[3] == 40 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 29 { ret 42 }
	ret 0
}
