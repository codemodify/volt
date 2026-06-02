package main
import "log"
import "strings"

fun isDigit(b byte) bool {
	if b < 48 { ret false }
	if b > 57 { ret false }
	ret true
}
fun isSpace(b byte) bool { ret b == 32 }
fun isLetter(b byte) bool {
	if b >= 65 { if b <= 90 { ret true } }
	if b >= 97 { if b <= 122 { ret true } }
	ret false
}
fun isAny(b byte) bool {
	if b < 0 { ret false }
	ret true
}
fun isNever(b byte) bool {
	if b > 255 { ret true }
	ret false
}

fun main() int {
	var pass int = 0

	// Longest digit run.
	if strings.LongestRunFunc("abc123def4567g89", isDigit) == 4 { pass = pass + 1 }    // "4567"
	if strings.LongestRunFunc("hello", isDigit) == 0 { pass = pass + 1 }
	if strings.LongestRunFunc("12345", isDigit) == 5 { pass = pass + 1 }

	// Longest space run.
	if strings.LongestRunFunc("a    b  c", isSpace) == 4 { pass = pass + 1 }
	if strings.LongestRunFunc("no-spaces", isSpace) == 0 { pass = pass + 1 }

	// Longest letter run.
	if strings.LongestRunFunc("abc123hello456world!", isLetter) == 5 { pass = pass + 1 }     // "hello"
	if strings.LongestRunFunc("a1b2c3", isLetter) == 1 { pass = pass + 1 }
	if strings.LongestRunFunc("ABCabcDEF", isLetter) == 9 { pass = pass + 1 }

	// Empty input.
	if strings.LongestRunFunc("", isDigit) == 0 { pass = pass + 1 }
	if strings.LongestRunFunc("", isAny) == 0 { pass = pass + 1 }

	// All-match.
	if strings.LongestRunFunc("aaaaa", isAny) == 5 { pass = pass + 1 }
	if strings.LongestRunFunc("xxx", isLetter) == 3 { pass = pass + 1 }

	// Never-match.
	if strings.LongestRunFunc("hello", isNever) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
