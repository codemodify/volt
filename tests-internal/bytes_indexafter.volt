package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// "hello world" = 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100
	var hay []byte = new(11) []byte { 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100 }
	var o []byte = new(1) []byte { 111 }       // "o"
	var world []byte = new(5) []byte { 119, 111, 114, 108, 100 }

	// IndexAfter — from=0 behaves like Index.
	if bytes.IndexAfter(hay, o, 0) == 4 { pass = pass + 1 }
	if bytes.IndexAfter(hay, world, 0) == 6 { pass = pass + 1 }

	// IndexAfter — skip past first match.
	if bytes.IndexAfter(hay, o, 5) == 7 { pass = pass + 1 }
	if bytes.IndexAfter(hay, o, 8) == -1 { pass = pass + 1 }

	// IndexAfter — negative from clamps to 0.
	if bytes.IndexAfter(hay, o, -3) == 4 { pass = pass + 1 }

	// IndexAfter — from past end → -1.
	if bytes.IndexAfter(hay, o, 100) == -1 { pass = pass + 1 }
	if bytes.IndexAfter(hay, o, 11) == -1 { pass = pass + 1 }

	// IndexAfter — empty sub returns from (clamped).
	var empty []byte = new(0) []byte {}
	if bytes.IndexAfter(hay, empty, 0) == 0 { pass = pass + 1 }
	if bytes.IndexAfter(hay, empty, 5) == 5 { pass = pass + 1 }
	if bytes.IndexAfter(hay, empty, 100) == 11 { pass = pass + 1 }       // clamp to len

	// IndexAfter — repeated iteration: comma-separated ints.
	// "a,b,c,d" = 97,44,98,44,99,44,100
	var csv []byte = new(7) []byte { 97, 44, 98, 44, 99, 44, 100 }
	var comma []byte = new(1) []byte { 44 }
	var idx1 int = bytes.IndexAfter(csv, comma, 0)
	var idx2 int = bytes.IndexAfter(csv, comma, idx1 + 1)
	var idx3 int = bytes.IndexAfter(csv, comma, idx2 + 1)
	var idx4 int = bytes.IndexAfter(csv, comma, idx3 + 1)
	if idx1 == 1 { pass = pass + 1 }
	if idx2 == 3 { pass = pass + 1 }
	if idx3 == 5 { pass = pass + 1 }
	if idx4 == -1 { pass = pass + 1 }

	// IndexAfter — match exactly at `from` boundary.
	// "aXa" = 97, 88, 97
	var trip []byte = new(3) []byte { 97, 88, 97 }
	var a []byte = new(1) []byte { 97 }
	if bytes.IndexAfter(trip, a, 0) == 0 { pass = pass + 1 }
	if bytes.IndexAfter(trip, a, 1) == 2 { pass = pass + 1 }
	if bytes.IndexAfter(trip, a, 2) == 2 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
