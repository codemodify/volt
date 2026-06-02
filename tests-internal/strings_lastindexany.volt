package main
import "log"
import "strings"
import "bytes"

fun main() int {
	var pass int = 0

	// strings.LastIndexAny — basic.
	if strings.LastIndexAny("hello world", "lo") == 9 { pass = pass + 1 }      // 'l' in "world" at index 9
	if strings.LastIndexAny("abcdef", "xyz") == -1 { pass = pass + 1 }
	if strings.LastIndexAny("", "abc") == -1 { pass = pass + 1 }
	if strings.LastIndexAny("hello", "") == -1 { pass = pass + 1 }
	if strings.LastIndexAny("", "") == -1 { pass = pass + 1 }

	// strings.LastIndexAny — single-char chars.
	if strings.LastIndexAny("abcabc", "a") == 3 { pass = pass + 1 }
	if strings.LastIndexAny("abcabc", "c") == 5 { pass = pass + 1 }

	// strings.LastIndexAny — chars not found at all.
	if strings.LastIndexAny("plain", "XYZ") == -1 { pass = pass + 1 }

	// strings.LastIndexAny — last char of s is a match.
	if strings.LastIndexAny("end!", "!?.") == 3 { pass = pass + 1 }

	// strings.LastIndexAny — first char of s is the only match.
	if strings.LastIndexAny("Hello", "H") == 0 { pass = pass + 1 }

	// strings.LastIndexAny — multiple matches; finds latest.
	if strings.LastIndexAny("a/b/c/d", "/") == 5 { pass = pass + 1 }

	// strings.LastIndexAny — typical use: rightmost punctuation.
	if strings.LastIndexAny("Hello, world!", ".!?") == 12 { pass = pass + 1 }

	// bytes.LastIndexAny — parallel checks.
	var s []byte = new(11) []byte { 104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100 }   // "hello world"
	var chars []byte = new(2) []byte { 108, 111 }   // "lo"
	if bytes.LastIndexAny(s, chars) == 9 { pass = pass + 1 }

	// bytes.LastIndexAny — no match.
	var none []byte = new(3) []byte { 120, 121, 122 }   // "xyz"
	if bytes.LastIndexAny(s, none) == -1 { pass = pass + 1 }

	// bytes.LastIndexAny — empty chars.
	var empty []byte = new(0) []byte {}
	if bytes.LastIndexAny(s, empty) == -1 { pass = pass + 1 }

	// bytes.LastIndexAny — empty input.
	var es []byte = new(0) []byte {}
	if bytes.LastIndexAny(es, chars) == -1 { pass = pass + 1 }

	// bytes.LastIndexAny — first byte is the only match.
	var first []byte = new(5) []byte { 72, 101, 108, 108, 111 }   // "Hello"
	var h []byte = new(1) []byte { 72 }   // "H"
	if bytes.LastIndexAny(first, h) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
