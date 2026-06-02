package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// IndexAfter — from=0 behaves like Index.
	if strings.IndexAfter("hello world", "o", 0) == 4 { pass = pass + 1 }
	if strings.IndexAfter("hello world", "world", 0) == 6 { pass = pass + 1 }
	if strings.IndexAfter("abc", "xyz", 0) == -1 { pass = pass + 1 }

	// IndexAfter — skip past the first match.
	if strings.IndexAfter("hello world", "o", 5) == 7 { pass = pass + 1 }   // second 'o'
	if strings.IndexAfter("hello world", "o", 8) == -1 { pass = pass + 1 }  // none after index 8

	// IndexAfter — repeated iteration "find next".
	var s string = "a,b,c,d"
	var idx1 int = strings.IndexAfter(s, ",", 0)        // 1
	var idx2 int = strings.IndexAfter(s, ",", idx1 + 1) // 3
	var idx3 int = strings.IndexAfter(s, ",", idx2 + 1) // 5
	var idx4 int = strings.IndexAfter(s, ",", idx3 + 1) // -1
	if idx1 == 1 { pass = pass + 1 }
	if idx2 == 3 { pass = pass + 1 }
	if idx3 == 5 { pass = pass + 1 }
	if idx4 == -1 { pass = pass + 1 }

	// IndexAfter — negative from clamps to 0.
	if strings.IndexAfter("abc", "a", -5) == 0 { pass = pass + 1 }

	// IndexAfter — from past end returns -1.
	if strings.IndexAfter("abc", "a", 100) == -1 { pass = pass + 1 }
	if strings.IndexAfter("abc", "a", 3) == -1 { pass = pass + 1 }    // past last

	// IndexAfter — from exactly at match boundary.
	if strings.IndexAfter("aXa", "a", 0) == 0 { pass = pass + 1 }     // first
	if strings.IndexAfter("aXa", "a", 1) == 2 { pass = pass + 1 }     // second
	if strings.IndexAfter("aXa", "a", 2) == 2 { pass = pass + 1 }     // exact

	// IndexAfter — empty sub returns from (clamped).
	if strings.IndexAfter("abc", "", 0) == 0 { pass = pass + 1 }
	if strings.IndexAfter("abc", "", 2) == 2 { pass = pass + 1 }
	if strings.IndexAfter("abc", "", 100) == 3 { pass = pass + 1 }    // clamp to len

	// IndexAfter — multi-char sub repeated scan.
	var hay string = "ab--ab--ab"
	if strings.IndexAfter(hay, "ab", 0) == 0 { pass = pass + 1 }
	if strings.IndexAfter(hay, "ab", 1) == 4 { pass = pass + 1 }
	if strings.IndexAfter(hay, "ab", 5) == 8 { pass = pass + 1 }
	if strings.IndexAfter(hay, "ab", 9) == -1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
