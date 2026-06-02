package main
import "log"
import "strings"

// Positive test: strings.WordCount + strings.NumLines.

fun main() int {
	var pass int = 0

	// WordCount — basic.
	if strings.WordCount("") == 0 { pass = pass + 1 }
	if strings.WordCount("hello") == 1 { pass = pass + 1 }
	if strings.WordCount("hello world") == 2 { pass = pass + 1 }
	if strings.WordCount("one two three four") == 4 { pass = pass + 1 }

	// WordCount — multiple-space delimiters collapse.
	if strings.WordCount("a   b   c") == 3 { pass = pass + 1 }

	// WordCount — leading / trailing whitespace ignored.
	if strings.WordCount("   foo   ") == 1 { pass = pass + 1 }
	if strings.WordCount("\t\nbar\n\t") == 1 { pass = pass + 1 }

	// WordCount — all-whitespace returns 0.
	if strings.WordCount("   ") == 0 { pass = pass + 1 }
	if strings.WordCount("\t\n\r ") == 0 { pass = pass + 1 }

	// WordCount — mixed whitespace bytes.
	if strings.WordCount("a\tb\nc\rd") == 4 { pass = pass + 1 }

	// WordCount — matches len(Fields).
	if strings.WordCount("the quick brown fox") == len(strings.Fields("the quick brown fox")) { pass = pass + 1 }

	// NumLines — basic.
	if strings.NumLines("") == 0 { pass = pass + 1 }
	if strings.NumLines("abc") == 1 { pass = pass + 1 }
	if strings.NumLines("abc\n") == 1 { pass = pass + 1 }
	if strings.NumLines("abc\ndef") == 2 { pass = pass + 1 }
	if strings.NumLines("abc\ndef\n") == 2 { pass = pass + 1 }

	// NumLines — lone newlines / multiple blanks.
	if strings.NumLines("\n") == 1 { pass = pass + 1 }
	if strings.NumLines("\n\n") == 2 { pass = pass + 1 }
	if strings.NumLines("\n\n\n") == 3 { pass = pass + 1 }

	// NumLines — multi-line.
	if strings.NumLines("a\nb\nc\nd\n") == 4 { pass = pass + 1 }
	if strings.NumLines("a\nb\nc\nd") == 4 { pass = pass + 1 }

	// NumLines — long line counts as one.
	if strings.NumLines("this is one long line with spaces") == 1 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
