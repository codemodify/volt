package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// LongestLine — basic.
	if strings.LongestLine("a\nbcde\nfgh") == 4 { pass = pass + 1 }
	if strings.LongestLine("hello") == 5 { pass = pass + 1 }
	if strings.LongestLine("") == 0 { pass = pass + 1 }

	// LongestLine — trailing newline.
	if strings.LongestLine("abc\nde\n") == 3 { pass = pass + 1 }

	// LongestLine — leading newline.
	if strings.LongestLine("\nabc") == 3 { pass = pass + 1 }

	// LongestLine — multi-newline.
	if strings.LongestLine("\n\n\n") == 0 { pass = pass + 1 }

	// LongestLine — equal lines.
	if strings.LongestLine("abc\ndef\nghi") == 3 { pass = pass + 1 }

	// LongestLine — last line longest.
	if strings.LongestLine("a\nbc\ndef\nghij") == 4 { pass = pass + 1 }

	// ShortestLine — basic.
	if strings.ShortestLine("a\nbcde\nfgh") == 1 { pass = pass + 1 }

	// ShortestLine — single line.
	if strings.ShortestLine("hello") == 5 { pass = pass + 1 }

	// ShortestLine — empty.
	if strings.ShortestLine("") == 0 { pass = pass + 1 }

	// ShortestLine — has empty lines.
	if strings.ShortestLine("abc\n\ndef") == 0 { pass = pass + 1 }

	// ShortestLine — trailing newline produces an empty trailing-line equivalent (counts as 0).
	if strings.ShortestLine("abc\n") == 0 { pass = pass + 1 }

	// ShortestLine — all-same.
	if strings.ShortestLine("aa\nbb\ncc") == 2 { pass = pass + 1 }

	// LongestLine + ShortestLine identity: equal for single-line input.
	if strings.LongestLine("solo") == strings.ShortestLine("solo") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
