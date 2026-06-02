package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// LastIndexByte — basic right-to-left scan.
	if strings.LastIndexByte("hello", 108) == 3 { pass = pass + 1 }    // last 'l'
	if strings.LastIndexByte("abcabc", 97) == 3 { pass = pass + 1 }    // last 'a'
	if strings.LastIndexByte("abcabc", 99) == 5 { pass = pass + 1 }    // last 'c'

	// LastIndexByte — single occurrence.
	if strings.LastIndexByte("Hello", 72) == 0 { pass = pass + 1 }     // 'H'
	if strings.LastIndexByte("Hello", 111) == 4 { pass = pass + 1 }    // 'o'

	// LastIndexByte — byte not present.
	if strings.LastIndexByte("hello", 122) == -1 { pass = pass + 1 }   // 'z'
	if strings.LastIndexByte("hello", 0) == -1 { pass = pass + 1 }     // NUL

	// LastIndexByte — empty string.
	if strings.LastIndexByte("", 97) == -1 { pass = pass + 1 }
	if strings.LastIndexByte("", 0) == -1 { pass = pass + 1 }

	// LastIndexByte — single-char string with match / miss.
	if strings.LastIndexByte("x", 120) == 0 { pass = pass + 1 }
	if strings.LastIndexByte("x", 121) == -1 { pass = pass + 1 }

	// Use case: extension lookup via the rightmost `.`.
	var fname string = "archive.tar.gz"
	var dotIdx int = strings.LastIndexByte(fname, 46)   // '.'
	if dotIdx == 11 { pass = pass + 1 }

	// Use case: filename via rightmost `/`.
	var path string = "/usr/local/bin/tool"
	var slashIdx int = strings.LastIndexByte(path, 47)
	if slashIdx == 14 { pass = pass + 1 }

	// Parallels IndexByte for first-occurrence symmetry.
	if strings.IndexByte("hello", 108) == 2 { pass = pass + 1 }        // first 'l'
	if strings.LastIndexByte("hello", 108) == 3 { pass = pass + 1 }    // last 'l'

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
