package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Basic.
	if strings.LongestRun("aaabbbcccc", 99) == 4 { pass = pass + 1 }   // 'c' x4
	if strings.LongestRun("aaabbbcccc", 97) == 3 { pass = pass + 1 }   // 'a' x3
	if strings.LongestRun("aaabbbcccc", 98) == 3 { pass = pass + 1 }   // 'b' x3

	// Byte not present.
	if strings.LongestRun("hello", 122) == 0 { pass = pass + 1 }       // 'z'

	// Empty input.
	if strings.LongestRun("", 97) == 0 { pass = pass + 1 }

	// All-same.
	if strings.LongestRun("xxxxx", 120) == 5 { pass = pass + 1 }

	// Single char.
	if strings.LongestRun("x", 120) == 1 { pass = pass + 1 }

	// Multiple runs, return the longest.
	if strings.LongestRun("aa-bbb-cc-dddd-e", 100) == 4 { pass = pass + 1 }     // 'd' x4
	if strings.LongestRun("aa-bbb-cc-dddd-e", 97) == 2 { pass = pass + 1 }      // 'a' x2

	// Run separated by other chars.
	if strings.LongestRun("aXaXaXa", 97) == 1 { pass = pass + 1 }

	// Long uninterrupted run.
	if strings.LongestRun("a----------b", 45) == 10 { pass = pass + 1 }    // 10 dashes

	// First-only / last-only run.
	if strings.LongestRun("xxxabcdef", 120) == 3 { pass = pass + 1 }
	if strings.LongestRun("abcdefxxx", 120) == 3 { pass = pass + 1 }

	// Spaces.
	if strings.LongestRun("a   b  c d", 32) == 3 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
