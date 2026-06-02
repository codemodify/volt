package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// ExpandTabs — no tabs in input is identity.
	if strings.ExpandTabs("hello", 4) == "hello" { pass = pass + 1 }
	if strings.ExpandTabs("", 4) == "" { pass = pass + 1 }

	// ExpandTabs — single tab at column 0 expands to tabSize spaces.
	if strings.ExpandTabs("\t", 4) == "    " { pass = pass + 1 }
	if strings.ExpandTabs("\t", 8) == "        " { pass = pass + 1 }

	// ExpandTabs — tab after content advances to next tab stop.
	if strings.ExpandTabs("a\t", 4) == "a   " { pass = pass + 1 }     // col 1 → 4, pad 3
	if strings.ExpandTabs("ab\t", 4) == "ab  " { pass = pass + 1 }    // col 2 → 4, pad 2
	if strings.ExpandTabs("abc\t", 4) == "abc " { pass = pass + 1 }   // col 3 → 4, pad 1
	if strings.ExpandTabs("abcd\t", 4) == "abcd    " { pass = pass + 1 } // col 4 → 8, pad 4

	// ExpandTabs — multiple tabs.
	if strings.ExpandTabs("\t\t", 4) == "        " { pass = pass + 1 }    // 8 spaces
	if strings.ExpandTabs("a\tb\t", 4) == "a   b   " { pass = pass + 1 }

	// ExpandTabs — newline resets column.
	if strings.ExpandTabs("a\n\t", 4) == "a\n    " { pass = pass + 1 }    // col resets after \n
	if strings.ExpandTabs("abc\n\t", 4) == "abc\n    " { pass = pass + 1 }

	// ExpandTabs — CR also resets column.
	if strings.ExpandTabs("a\r\t", 4) == "a\r    " { pass = pass + 1 }

	// ExpandTabs — non-zero / non-default sizes.
	if strings.ExpandTabs("\t", 2) == "  " { pass = pass + 1 }
	if strings.ExpandTabs("a\tb", 2) == "a b" { pass = pass + 1 }         // col 1 → 2, pad 1
	if strings.ExpandTabs("\t", 1) == " " { pass = pass + 1 }

	// ExpandTabs — tabSize <= 0 passes through unchanged.
	if strings.ExpandTabs("a\tb", 0) == "a\tb" { pass = pass + 1 }
	if strings.ExpandTabs("a\tb", -1) == "a\tb" { pass = pass + 1 }

	// ExpandTabs — mixed multi-line text.
	if strings.ExpandTabs("a\tb\nc\td", 4) == "a   b\nc   d" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
