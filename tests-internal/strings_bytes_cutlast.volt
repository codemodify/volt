package main
import "log"
import "strings"
import "bytes"

// Positive test: strings.CutLast + bytes.CutLast.

fun main() int {
	var pass int = 0

	var before string = ""
	var after string = ""
	var found bool = false

	// strings.CutLast — multiple occurrences picks the last.
	before, after, found = strings.CutLast("a.b.c.d", ".")
	if before == "a.b.c" { pass = pass + 1 }
	if after == "d" { pass = pass + 1 }
	if found { pass = pass + 1 }

	// File path / extension split.
	before, after, found = strings.CutLast("archive.tar.gz", ".")
	if before == "archive.tar" { pass = pass + 1 }
	if after == "gz" { pass = pass + 1 }

	// Path-vs-basename split.
	before, after, found = strings.CutLast("/usr/local/bin/cmd", "/")
	if before == "/usr/local/bin" { pass = pass + 1 }
	if after == "cmd" { pass = pass + 1 }

	// No separator.
	before, after, found = strings.CutLast("hello", "x")
	if before == "hello" { pass = pass + 1 }
	if after == "" { pass = pass + 1 }
	if !found { pass = pass + 1 }

	// Empty sep returns (s, "", true).
	before, after, found = strings.CutLast("hello", "")
	if before == "hello" { pass = pass + 1 }
	if after == "" { pass = pass + 1 }
	if found { pass = pass + 1 }

	// Empty s.
	before, after, found = strings.CutLast("", ".")
	if before == "" { pass = pass + 1 }
	if !found { pass = pass + 1 }

	// bytes.CutLast — basic.
	var bb []byte = new(0) []byte {}
	var ab []byte = new(0) []byte {}
	var bf bool = false
	bb, ab, bf = bytes.CutLast(new(7) []byte { 97, 46, 98, 46, 99, 46, 100 }, new(1) []byte { 46 })   // "a.b.c.d" / "."
	if len(bb) == 5 { pass = pass + 1 }   // "a.b.c"
	if len(ab) == 1 { pass = pass + 1 }   // "d"
	if ab[0] == 100 { pass = pass + 1 }
	if bf { pass = pass + 1 }

	// bytes.CutLast — no match.
	bb, ab, bf = bytes.CutLast(new(3) []byte { 1, 2, 3 }, new(1) []byte { 99 })
	if !bf { pass = pass + 1 }
	if len(bb) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
