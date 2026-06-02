package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// AbbreviateLeft — basic.
	if strings.AbbreviateLeft("/very/long/path/file.txt", 12, "...") == ".../file.txt" { pass = pass + 1 }

	// AbbreviateLeft — passes through when short.
	if strings.AbbreviateLeft("abc", 10, "...") == "abc" { pass = pass + 1 }

	// AbbreviateLeft — exact fit.
	if strings.AbbreviateLeft("hello", 5, "...") == "hello" { pass = pass + 1 }

	// AbbreviateLeft — single-char ellipsis.
	if strings.AbbreviateLeft("abcdefgh", 5, "*") == "*efgh" { pass = pass + 1 }

	// AbbreviateLeft — empty ellipsis.
	if strings.AbbreviateLeft("abcdef", 4, "") == "cdef" { pass = pass + 1 }

	// AbbreviateLeft — ellipsis longer than maxBytes.
	if strings.AbbreviateLeft("hello world", 2, "...") == ".." { pass = pass + 1 }

	// AbbreviateLeft — maxBytes <= 0 returns "".
	if strings.AbbreviateLeft("hello", 0, "...") == "" { pass = pass + 1 }
	if strings.AbbreviateLeft("hello", -1, "...") == "" { pass = pass + 1 }

	// AbbreviateLeft — empty.
	if strings.AbbreviateLeft("", 10, "...") == "" { pass = pass + 1 }

	// AbbreviateLeft — keeps the tail (rightmost portion).
	if strings.AbbreviateLeft("abcdefghij", 6, "...") == "...hij" { pass = pass + 1 }

	// AbbreviateLeft — useful for long IDs (keeps last 7 after 3-byte ellipsis).
	if strings.AbbreviateLeft("commit-abc123def456789", 10, "...") == "...f456789" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 11 { ret 42 }
	ret 0
}
