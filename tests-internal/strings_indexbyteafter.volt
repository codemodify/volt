package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// from=0 → like IndexByte.
	if strings.IndexByteAfter("hello", 108, 0) == 2 { pass = pass + 1 }   // first 'l'
	if strings.IndexByteAfter("hello", 111, 0) == 4 { pass = pass + 1 }   // 'o'

	// from past first occurrence skips it.
	if strings.IndexByteAfter("hello", 108, 3) == 3 { pass = pass + 1 }   // 'l' at idx 3
	if strings.IndexByteAfter("hello", 108, 4) == -1 { pass = pass + 1 }  // none after

	// Iteration pattern — find all commas in "a,b,c".
	var s string = "a,b,c"
	var i1 int = strings.IndexByteAfter(s, 44, 0)
	var i2 int = strings.IndexByteAfter(s, 44, i1 + 1)
	var i3 int = strings.IndexByteAfter(s, 44, i2 + 1)
	if i1 == 1 { pass = pass + 1 }
	if i2 == 3 { pass = pass + 1 }
	if i3 == -1 { pass = pass + 1 }

	// Negative from clamps to 0.
	if strings.IndexByteAfter("abc", 97, -5) == 0 { pass = pass + 1 }

	// from past end → -1.
	if strings.IndexByteAfter("abc", 97, 100) == -1 { pass = pass + 1 }
	if strings.IndexByteAfter("abc", 97, 3) == -1 { pass = pass + 1 }

	// Empty string.
	if strings.IndexByteAfter("", 97, 0) == -1 { pass = pass + 1 }

	// Match at exact `from` boundary.
	if strings.IndexByteAfter("aXa", 97, 0) == 0 { pass = pass + 1 }
	if strings.IndexByteAfter("aXa", 97, 1) == 2 { pass = pass + 1 }
	if strings.IndexByteAfter("aXa", 97, 2) == 2 { pass = pass + 1 }

	// Byte not present at all.
	if strings.IndexByteAfter("hello", 122, 0) == -1 { pass = pass + 1 }

	// Use case: 3-line source, find `\n` boundaries.
	var src string = "alpha\nbeta\ngamma"
	var ln1 int = strings.IndexByteAfter(src, 10, 0)
	var ln2 int = strings.IndexByteAfter(src, 10, ln1 + 1)
	var ln3 int = strings.IndexByteAfter(src, 10, ln2 + 1)
	if ln1 == 5 { pass = pass + 1 }
	if ln2 == 10 { pass = pass + 1 }
	if ln3 == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
