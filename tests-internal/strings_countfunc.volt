package main
import "log"
import "strings"

fun isDigit(b byte) bool {
	if b < 48 { ret false }
	if b > 57 { ret false }
	ret true
}

fun isUpper(b byte) bool {
	if b < 65 { ret false }
	if b > 90 { ret false }
	ret true
}

fun isVowel(b byte) bool {
	if b == 97 { ret true }   // a
	if b == 101 { ret true }  // e
	if b == 105 { ret true }  // i
	if b == 111 { ret true }  // o
	if b == 117 { ret true }  // u
	ret false
}

fun isSpace(b byte) bool {
	if b == 32 { ret true }
	if b == 9 { ret true }
	if b == 10 { ret true }
	ret false
}

fun isAny(b byte) bool {
	if b == 0 { ret true }
	ret true
}

fun isNone(b byte) bool {
	if b == 0 { ret false }
	ret false
}

fun main() int {
	var pass int = 0

	// Empty s → 0.
	if strings.CountFunc("", isDigit) == 0 { pass = pass + 1 }

	// Digits.
	if strings.CountFunc("hello123", isDigit) == 3 { pass = pass + 1 }
	if strings.CountFunc("abc", isDigit) == 0 { pass = pass + 1 }
	if strings.CountFunc("12345", isDigit) == 5 { pass = pass + 1 }

	// Uppercase letters.
	if strings.CountFunc("Hello World", isUpper) == 2 { pass = pass + 1 }
	if strings.CountFunc("hello world", isUpper) == 0 { pass = pass + 1 }
	if strings.CountFunc("HELLO", isUpper) == 5 { pass = pass + 1 }

	// Vowels.
	if strings.CountFunc("hello world", isVowel) == 3 { pass = pass + 1 }
	if strings.CountFunc("aeiou", isVowel) == 5 { pass = pass + 1 }
	if strings.CountFunc("xyz", isVowel) == 0 { pass = pass + 1 }

	// Whitespace (space, tab, newline).
	if strings.CountFunc("hello world", isSpace) == 1 { pass = pass + 1 }
	if strings.CountFunc("a b\tc\nd", isSpace) == 3 { pass = pass + 1 }
	if strings.CountFunc("nospace", isSpace) == 0 { pass = pass + 1 }

	// Always-true predicate → len(s).
	if strings.CountFunc("hello", isAny) == 5 { pass = pass + 1 }
	if strings.CountFunc("", isAny) == 0 { pass = pass + 1 }

	// Always-false predicate → 0.
	if strings.CountFunc("hello", isNone) == 0 { pass = pass + 1 }

	// Single-char string.
	if strings.CountFunc("a", isVowel) == 1 { pass = pass + 1 }
	if strings.CountFunc("z", isVowel) == 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
