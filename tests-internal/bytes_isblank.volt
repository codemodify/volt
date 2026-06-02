package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// Empty → true (vacuous truth, matches strings.IsBlank).
	var empty []byte = new(0) []byte {}
	if bytes.IsBlank(empty) { pass = pass + 1 }

	// Single space → true.
	var space []byte = new(1) []byte { 32 }
	if bytes.IsBlank(space) { pass = pass + 1 }

	// All whitespace bytes individually.
	var tab []byte = new(1) []byte { 9 }
	if bytes.IsBlank(tab) { pass = pass + 1 }

	var lf []byte = new(1) []byte { 10 }
	if bytes.IsBlank(lf) { pass = pass + 1 }

	var cr []byte = new(1) []byte { 13 }
	if bytes.IsBlank(cr) { pass = pass + 1 }

	var vt []byte = new(1) []byte { 11 }
	if bytes.IsBlank(vt) { pass = pass + 1 }

	var ff []byte = new(1) []byte { 12 }
	if bytes.IsBlank(ff) { pass = pass + 1 }

	// Mixed whitespace.
	var mix []byte = new(6) []byte { 32, 9, 10, 13, 11, 12 }
	if bytes.IsBlank(mix) { pass = pass + 1 }

	// Single non-ws byte → false.
	var letter []byte = new(1) []byte { 97 }   // 'a'
	if !bytes.IsBlank(letter) { pass = pass + 1 }

	// One non-ws in middle → false.
	var oneLetter []byte = new(3) []byte { 32, 97, 32 }
	if !bytes.IsBlank(oneLetter) { pass = pass + 1 }

	// Long whitespace run.
	var long []byte = new(100) []byte {}
	for i := 0; i < 100; i++ { long[i] = 32 }
	if bytes.IsBlank(long) { pass = pass + 1 }

	// Long whitespace with one non-ws.
	var longMix []byte = new(100) []byte {}
	for i := 0; i < 100; i++ { longMix[i] = 32 }
	longMix[50] = 65   // 'A'
	if !bytes.IsBlank(longMix) { pass = pass + 1 }

	// Non-printable non-whitespace (NUL) is non-blank.
	var nul []byte = new(1) []byte { 0 }
	if !bytes.IsBlank(nul) { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
