package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// Empty.
	var empty []byte = new(0) []byte {}
	var r1 []byte = bytes.OnlyAscii(empty)
	if len(r1) == 0 { pass = pass + 1 }

	// All-ASCII.
	var ascii []byte = new(5) []byte { 104, 101, 108, 108, 111 }   // "hello"
	var r2 []byte = bytes.OnlyAscii(ascii)
	if len(r2) == 5 { pass = pass + 1 }
	if r2[0] == 104 { pass = pass + 1 }
	if r2[4] == 111 { pass = pass + 1 }

	// Control bytes kept (still < 128).
	var ctrl []byte = new(4) []byte { 0, 10, 9, 127 }
	var r3 []byte = bytes.OnlyAscii(ctrl)
	if len(r3) == 4 { pass = pass + 1 }
	if r3[3] == 127 { pass = pass + 1 }

	// 128 (0x80) is the first non-ASCII — stripped.
	// "a\x80b" = 97, 128, 98
	var withMid []byte = new(3) []byte { 97, 128, 98 }
	var r4 []byte = bytes.OnlyAscii(withMid)
	if len(r4) == 2 { pass = pass + 1 }
	if r4[0] == 97 { pass = pass + 1 }
	if r4[1] == 98 { pass = pass + 1 }

	// UTF-8 é (0xc3 0xa9) interleaved with ASCII.
	// "caf\xc3\xa9" = 99, 97, 102, 195, 169
	var caffe []byte = new(5) []byte { 99, 97, 102, 195, 169 }
	var r5 []byte = bytes.OnlyAscii(caffe)
	if len(r5) == 3 { pass = pass + 1 }
	if r5[0] == 99 { pass = pass + 1 }
	if r5[2] == 102 { pass = pass + 1 }

	// All non-ASCII → empty.
	var hi []byte = new(4) []byte { 195, 169, 226, 130 }   // partial UTF-8 sequences
	var r6 []byte = bytes.OnlyAscii(hi)
	if len(r6) == 0 { pass = pass + 1 }

	// 0xff (255) stripped.
	var xff []byte = new(3) []byte { 120, 255, 121 }
	var r7 []byte = bytes.OnlyAscii(xff)
	if len(r7) == 2 { pass = pass + 1 }
	if r7[0] == 120 { pass = pass + 1 }
	if r7[1] == 121 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
