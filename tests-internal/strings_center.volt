package main
import "log"
import "strings"

// Positive test: strings.Center.

fun main() int {
	var pass int = 0

	// Even total padding.
	if strings.Center("hi", 6, 32) == "  hi  " { pass = pass + 1 }
	// Odd total padding — extra on the right.
	if strings.Center("hi", 5, 32) == " hi  " { pass = pass + 1 }
	// Already long enough → unchanged.
	if strings.Center("hello", 3, 32) == "hello" { pass = pass + 1 }
	// Exact length.
	if strings.Center("hello", 5, 32) == "hello" { pass = pass + 1 }
	// One char short — odd-pad gives 0 left + 1 right.
	if strings.Center("hello", 6, 32) == "hello " { pass = pass + 1 }
	// Two chars short — even-pad gives 1 left + 1 right.
	if strings.Center("hello", 7, 32) == " hello " { pass = pass + 1 }
	// Pad with '*'.
	if strings.Center("X", 5, 42) == "**X**" { pass = pass + 1 }
	// Pad with '*' odd → right gets the extra.
	if strings.Center("X", 4, 42) == "*X**" { pass = pass + 1 }
	// Empty s.
	if strings.Center("", 4, 45) == "----" { pass = pass + 1 }
	// Empty s odd width.
	if strings.Center("", 3, 45) == "---" { pass = pass + 1 }
	// n=0.
	if strings.Center("ab", 0, 32) == "ab" { pass = pass + 1 }
	// n < 0.
	if strings.Center("ab", -1, 32) == "ab" { pass = pass + 1 }
	// Composite — center, then PadLeft.
	var header string = strings.Center("TITLE", 7, 45)
	if header == "-TITLE-" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
