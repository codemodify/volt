package main
import "log"
import "strings"

// Positive test: strings.RuneSplit + strings.RuneIndexFromByte.

fun main() int {
	var pass int = 0

	// RuneSplit ASCII.
	var a []string = strings.RuneSplit("hello")
	if len(a) == 5 { pass = pass + 1 }
	if a[0] == "h" { pass = pass + 1 }
	if a[4] == "o" { pass = pass + 1 }

	// Empty.
	if len(strings.RuneSplit("")) == 0 { pass = pass + 1 }

	// Single char.
	var s1 []string = strings.RuneSplit("z")
	if len(s1) == 1 { pass = pass + 1 }
	if s1[0] == "z" { pass = pass + 1 }

	// UTF-8 multi-byte — "caf\xC3\xA9" is 4 runes.
	var c []string = strings.RuneSplit("caf\xC3\xA9")
	if len(c) == 4 { pass = pass + 1 }
	if c[0] == "c" { pass = pass + 1 }
	if c[3] == "\xC3\xA9" { pass = pass + 1 }

	// 3-byte runes.
	var cjk []string = strings.RuneSplit("\xE4\xB8\x96\xE7\x95\x8C")
	if len(cjk) == 2 { pass = pass + 1 }
	if cjk[0] == "\xE4\xB8\x96" { pass = pass + 1 }

	// 4-byte emoji.
	var em []string = strings.RuneSplit("a\xF0\x9F\x98\x80b")
	if len(em) == 3 { pass = pass + 1 }
	if em[1] == "\xF0\x9F\x98\x80" { pass = pass + 1 }

	// RuneIndexFromByte — ASCII.
	if strings.RuneIndexFromByte("hello", 0) == 0 { pass = pass + 1 }
	if strings.RuneIndexFromByte("hello", 1) == 1 { pass = pass + 1 }
	if strings.RuneIndexFromByte("hello", 4) == 4 { pass = pass + 1 }
	if strings.RuneIndexFromByte("hello", 5) == 5 { pass = pass + 1 }   // one past

	// Out-of-range.
	if strings.RuneIndexFromByte("hello", 6) == -1 { pass = pass + 1 }
	if strings.RuneIndexFromByte("hello", -1) == -1 { pass = pass + 1 }

	// UTF-8 boundary positions.
	if strings.RuneIndexFromByte("caf\xC3\xA9", 0) == 0 { pass = pass + 1 }
	if strings.RuneIndexFromByte("caf\xC3\xA9", 3) == 3 { pass = pass + 1 }   // start of é
	if strings.RuneIndexFromByte("caf\xC3\xA9", 5) == 4 { pass = pass + 1 }   // one past

	// Mid-rune → -1.
	if strings.RuneIndexFromByte("caf\xC3\xA9", 4) == -1 { pass = pass + 1 }   // mid-é

	// Roundtrip — ByteIndexRune(s, RuneIndexFromByte(s, b)) == b when b is on a boundary.
	var b int = strings.ByteIndexRune("caf\xC3\xA9", 3)   // 3
	var r int = strings.RuneIndexFromByte("caf\xC3\xA9", b)
	if r == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
