package main
import "log"
import "bytes"

fun main() int {
	var pass int = 0

	// "aaabbbcccc" — 'c' x4 wins.
	var s1 []byte = new(10) []byte { 97, 97, 97, 98, 98, 98, 99, 99, 99, 99 }
	if bytes.LongestRun(s1, 99) == 4 { pass = pass + 1 }
	if bytes.LongestRun(s1, 97) == 3 { pass = pass + 1 }
	if bytes.LongestRun(s1, 98) == 3 { pass = pass + 1 }
	if bytes.LongestRun(s1, 122) == 0 { pass = pass + 1 }   // 'z' absent

	// Empty.
	var empty []byte = new(0) []byte {}
	if bytes.LongestRun(empty, 97) == 0 { pass = pass + 1 }

	// Single byte match.
	var solo []byte = new(1) []byte { 120 }
	if bytes.LongestRun(solo, 120) == 1 { pass = pass + 1 }
	if bytes.LongestRun(solo, 121) == 0 { pass = pass + 1 }

	// All-same.
	var allx []byte = new(5) []byte { 120, 120, 120, 120, 120 }
	if bytes.LongestRun(allx, 120) == 5 { pass = pass + 1 }

	// Two separate runs — longest wins.
	// "aaxxxxx aa" = 5 'x's
	var two []byte = new(8) []byte { 97, 97, 120, 120, 120, 120, 120, 97 }
	if bytes.LongestRun(two, 120) == 5 { pass = pass + 1 }

	// NUL bytes (binary case).
	var nuls []byte = new(8) []byte { 65, 0, 0, 0, 0, 66, 0, 0 }
	if bytes.LongestRun(nuls, 0) == 4 { pass = pass + 1 }

	// Run at start.
	var startRun []byte = new(6) []byte { 45, 45, 45, 97, 98, 99 }
	if bytes.LongestRun(startRun, 45) == 3 { pass = pass + 1 }

	// Run at end.
	var endRun []byte = new(6) []byte { 97, 98, 99, 45, 45, 45 }
	if bytes.LongestRun(endRun, 45) == 3 { pass = pass + 1 }

	// Repeated 1-byte runs.
	var alt []byte = new(7) []byte { 97, 88, 97, 88, 97, 88, 97 }
	if bytes.LongestRun(alt, 97) == 1 { pass = pass + 1 }
	if bytes.LongestRun(alt, 88) == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
