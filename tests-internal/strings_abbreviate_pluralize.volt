package main
import "log"
import "strings"

// Positive test: strings.AbbreviateMiddle + strings.Pluralize.

fun main() int {
	var pass int = 0

	// AbbreviateMiddle — short input passes through.
	if strings.AbbreviateMiddle("abc", 10, "...") == "abc" { pass = pass + 1 }
	if strings.AbbreviateMiddle("", 10, "...") == "" { pass = pass + 1 }

	// AbbreviateMiddle — exact-fit passes through.
	if strings.AbbreviateMiddle("hello", 5, "...") == "hello" { pass = pass + 1 }

	// AbbreviateMiddle — basic clipping with 3-byte ellipsis.
	// "abcdefghij" len=10, maxBytes=8, ellipsis="..."(3)
	// available = 5, leftLen = 3 (ceil), rightLen = 2
	// → "abc" + "..." + "ij" = "abc...ij"
	if strings.AbbreviateMiddle("abcdefghij", 8, "...") == "abc...ij" { pass = pass + 1 }

	// AbbreviateMiddle — path shortening.
	// "/very/long/path/file.txt" len=24, maxBytes=12, ellipsis="..."(3)
	// available = 9, leftLen = 5, rightLen = 4
	// → "/very" + "..." + ".txt" = "/very....txt"
	if strings.AbbreviateMiddle("/very/long/path/file.txt", 12, "...") == "/very....txt" { pass = pass + 1 }

	// AbbreviateMiddle — single-char ellipsis.
	// "abcdefgh" len=8, maxBytes=5, ellipsis="*"(1)
	// available = 4, leftLen = 2, rightLen = 2
	// → "ab" + "*" + "gh" = "ab*gh"
	if strings.AbbreviateMiddle("abcdefgh", 5, "*") == "ab*gh" { pass = pass + 1 }

	// AbbreviateMiddle — empty ellipsis.
	// "abcdef" len=6, maxBytes=4, ellipsis=""(0)
	// available = 4, leftLen = 2, rightLen = 2
	// → "ab" + "" + "ef" = "abef"
	if strings.AbbreviateMiddle("abcdef", 4, "") == "abef" { pass = pass + 1 }

	// AbbreviateMiddle — ellipsis larger than maxBytes (head-truncate fallback).
	if strings.AbbreviateMiddle("abcdefgh", 2, "...") == "ab" { pass = pass + 1 }

	// AbbreviateMiddle — maxBytes <= 0 returns "".
	if strings.AbbreviateMiddle("hello", 0, "...") == "" { pass = pass + 1 }
	if strings.AbbreviateMiddle("hello", -1, "...") == "" { pass = pass + 1 }

	// Pluralize — basic English.
	if strings.Pluralize("item", 0) == "items" { pass = pass + 1 }
	if strings.Pluralize("item", 1) == "item" { pass = pass + 1 }
	if strings.Pluralize("item", 2) == "items" { pass = pass + 1 }
	if strings.Pluralize("item", 100) == "items" { pass = pass + 1 }

	// Pluralize — empty word.
	if strings.Pluralize("", 1) == "" { pass = pass + 1 }
	if strings.Pluralize("", 5) == "s" { pass = pass + 1 }

	// Pluralize — negative quantity treated as plural (English) except ±1.
	if strings.Pluralize("apple", -1) == "apple" { pass = pass + 1 }
	if strings.Pluralize("apple", -5) == "apples" { pass = pass + 1 }

	// Pluralize — long word.
	if strings.Pluralize("strawberry", 2) == "strawberrys" { pass = pass + 1 }   // naive "-s", no "-ies"

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
