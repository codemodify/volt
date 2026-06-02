package main
import "log"
import "os"
import "bytes"
import "strings"

// Positive test: os.TempDir + bytes.Map. Standard Linux env always
// has a usable TempDir (defaults to "/tmp" when $TMPDIR is unset).
// bytes.Map applies a byte-transform fn over every byte.

fun inc(b byte) byte { ret b + 1 }
fun toLowerOne(b byte) byte {
	if b >= 65 {
		if b <= 90 { ret b + 32 }
	}
	ret b
}

fun main() int {
	var pass int = 0

	// TempDir: non-empty, starts with '/'.
	var t string = os.TempDir()
	if len(t) > 0 { pass = pass + 1 }
	if strings.HasPrefix(t, "/") { pass = pass + 1 }
	// In our env $TMPDIR isn't set → defaults to "/tmp".
	var x string = os.Getenv("TMPDIR")
	if len(x) == 0 {
		if t == "/tmp" { pass = pass + 1 }
	} else {
		if t == x { pass = pass + 1 }
	}

	// bytes.Map: shift each byte by +1.
	var s1 []byte = new(3) []byte{65, 66, 67}    // ABC
	var r1 []byte = bytes.Map(inc, s1)
	if len(r1) == 3 { pass = pass + 1 }
	if r1[0] == 66 { pass = pass + 1 }
	if r1[1] == 67 { pass = pass + 1 }
	if r1[2] == 68 { pass = pass + 1 }

	// bytes.Map: ASCII upper → lower.
	var s2 []byte = new(5) []byte{72, 73, 33, 65, 90}  // "HI!AZ"
	var r2 []byte = bytes.Map(toLowerOne, s2)
	if r2[0] == 104 { pass = pass + 1 }
	if r2[1] == 105 { pass = pass + 1 }
	if r2[2] == 33 { pass = pass + 1 }   // '!' passes through
	if r2[3] == 97 { pass = pass + 1 }
	if r2[4] == 122 { pass = pass + 1 }

	// bytes.Map: empty input.
	var s3 []byte = new(0) []byte{}
	var r3 []byte = bytes.Map(inc, s3)
	if len(r3) == 0 { pass = pass + 1 }

	log.Println("pass=%d tempdir=%s", pass, t)
	if pass == 13 { ret 42 }
	ret 0
}
