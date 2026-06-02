package main
import "log"
import "strings"

// Positive test: strings.PadLeft / PadRight.

fun main() int {
	var pass int = 0

	// PadLeft with spaces.
	if strings.PadLeft("42", 5, 32) == "   42" { pass = pass + 1 }
	// PadLeft with zeros.
	if strings.PadLeft("7", 4, 48) == "0007" { pass = pass + 1 }
	// PadLeft when s is already long enough → unchanged.
	if strings.PadLeft("hello", 3, 32) == "hello" { pass = pass + 1 }
	if strings.PadLeft("hello", 5, 32) == "hello" { pass = pass + 1 }   // exact length
	// PadLeft empty s.
	if strings.PadLeft("", 3, 88) == "XXX" { pass = pass + 1 }   // 'X'
	// PadLeft with n=0 / negative.
	if strings.PadLeft("ab", 0, 32) == "ab" { pass = pass + 1 }
	if strings.PadLeft("ab", -1, 32) == "ab" { pass = pass + 1 }

	// PadRight with spaces.
	if strings.PadRight("42", 5, 32) == "42   " { pass = pass + 1 }
	// PadRight with dots.
	if strings.PadRight("loading", 10, 46) == "loading..." { pass = pass + 1 }
	// PadRight unchanged.
	if strings.PadRight("hello", 3, 32) == "hello" { pass = pass + 1 }
	if strings.PadRight("hello", 5, 32) == "hello" { pass = pass + 1 }
	// PadRight empty s.
	if strings.PadRight("", 3, 45) == "---" { pass = pass + 1 }   // '-'
	// PadRight with n=0 / negative.
	if strings.PadRight("ab", 0, 32) == "ab" { pass = pass + 1 }

	// Combine: build a small column.
	var col string = strings.PadLeft("1", 3, 32) + "|" + strings.PadRight("a", 3, 32)
	if col == "  1|a  " { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
