package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.IndexNthByte("", 65, 0) == -1 { pass = pass + 1 }
	if strings.IndexNth("", "x", 0) == -1 { pass = pass + 1 }

	// No occurrence.
	if strings.IndexNthByte("abc", 88, 0) == -1 { pass = pass + 1 }
	if strings.IndexNth("abc", "xyz", 0) == -1 { pass = pass + 1 }

	// IndexNthByte: comma positions.
	var csv string = "a,b,c,d,e"
	if strings.IndexNthByte(csv, 44, 0) == 1 { pass = pass + 1 }   // ',' = 44
	if strings.IndexNthByte(csv, 44, 1) == 3 { pass = pass + 1 }
	if strings.IndexNthByte(csv, 44, 2) == 5 { pass = pass + 1 }
	if strings.IndexNthByte(csv, 44, 3) == 7 { pass = pass + 1 }
	if strings.IndexNthByte(csv, 44, 4) == -1 { pass = pass + 1 }   // only 4 commas

	// IndexNth substring.
	var s1 string = "foobarfoobazfoo"
	if strings.IndexNth(s1, "foo", 0) == 0 { pass = pass + 1 }
	if strings.IndexNth(s1, "foo", 1) == 6 { pass = pass + 1 }
	if strings.IndexNth(s1, "foo", 2) == 12 { pass = pass + 1 }
	if strings.IndexNth(s1, "foo", 3) == -1 { pass = pass + 1 }

	// Non-overlapping advance: "aaaa", search "aa".
	// Positions: 0 (matches "aa"), advance by 2 → 2 (matches), advance → 4 (end).
	if strings.IndexNth("aaaa", "aa", 0) == 0 { pass = pass + 1 }
	if strings.IndexNth("aaaa", "aa", 1) == 2 { pass = pass + 1 }
	if strings.IndexNth("aaaa", "aa", 2) == -1 { pass = pass + 1 }

	// Empty sub returns -1.
	if strings.IndexNth("hello", "", 0) == -1 { pass = pass + 1 }

	// n < 0.
	if strings.IndexNth("hello", "l", -1) == -1 { pass = pass + 1 }
	if strings.IndexNthByte("hello", 108, -1) == -1 { pass = pass + 1 }

	// Single-char sub vs IndexNthByte equivalence.
	var pos1 int = strings.IndexNth("abracadabra", "a", 2)
	var pos2 int = strings.IndexNthByte("abracadabra", 97, 2)
	if pos1 == pos2 { pass = pass + 1 }

	// Cross-property: IndexNth(s, sub, n) == IndicesOf(s, sub)[n] when valid.
	var s2 string = "aXbXcXdXe"
	var indices []int = strings.IndicesOf(s2, "X")
	if strings.IndexNth(s2, "X", 2) == indices[2] { pass = pass + 1 }

	// Tab use case: parse Nth column from tab-separated record.
	var rec string = "col1\tcol2\tcol3\tcol4"
	if strings.IndexNthByte(rec, 9, 1) == 9 { pass = pass + 1 }   // second '\t' at index 9
	if strings.IndexNthByte(rec, 9, 2) == 14 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
