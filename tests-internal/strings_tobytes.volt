package main
import "log"
import "strings"
import "bytes"

fun main() int {
	var pass int = 0

	// Empty.
	var r1 []byte = strings.ToBytes("")
	if len(r1) == 0 { pass = pass + 1 }

	// Simple ASCII.
	var r2 []byte = strings.ToBytes("hello")
	if len(r2) == 5 { pass = pass + 1 }
	if r2[0] == 104 { pass = pass + 1 }
	if r2[4] == 111 { pass = pass + 1 }

	// Round-trip with bytes.String.
	if bytes.String(strings.ToBytes("world")) == "world" { pass = pass + 1 }
	if bytes.String(strings.ToBytes("")) == "" { pass = pass + 1 }

	// Single byte.
	var r3 []byte = strings.ToBytes("A")
	if len(r3) == 1 { pass = pass + 1 }
	if r3[0] == 65 { pass = pass + 1 }

	// Non-ASCII bytes preserved.
	var r4 []byte = strings.ToBytes("\xc3\xa9")
	if len(r4) == 2 { pass = pass + 1 }

	// Result is defensive copy — can be used with bytes APIs.
	var r5 []byte = strings.ToBytes("test")
	if bytes.HasPrefix(r5, strings.ToBytes("te")) { pass = pass + 1 }

	// Long string.
	var s string = "this is a longer string for testing"
	var r6 []byte = strings.ToBytes(s)
	if len(r6) == len(s) { pass = pass + 1 }
	if r6[0] == 116 { pass = pass + 1 }   // 't'
	if r6[34] == 103 { pass = pass + 1 }  // 'g'

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
