package main
import "log"
import "strings"

// Positive test: strings.OnlyLetters + strings.MaskMiddle.

fun main() int {
	var pass int = 0

	// OnlyLetters — basic.
	if strings.OnlyLetters("hello 123 world") == "helloworld" { pass = pass + 1 }
	if strings.OnlyLetters("a1b2c3") == "abc" { pass = pass + 1 }

	// OnlyLetters — preserve case.
	if strings.OnlyLetters("Hi-There!") == "HiThere" { pass = pass + 1 }

	// OnlyLetters — empty / no letters.
	if strings.OnlyLetters("") == "" { pass = pass + 1 }
	if strings.OnlyLetters("12345") == "" { pass = pass + 1 }
	if strings.OnlyLetters("...") == "" { pass = pass + 1 }

	// OnlyLetters — letters only.
	if strings.OnlyLetters("ABCdef") == "ABCdef" { pass = pass + 1 }

	// OnlyLetters — Unicode (multi-byte UTF-8) bytes drop.
	if strings.OnlyLetters("café") == "caf" { pass = pass + 1 }

	// MaskMiddle — basic.
	if strings.MaskMiddle("5551234567", 3, 4, 42) == "555***4567" { pass = pass + 1 }   // '*' = 42

	// MaskMiddle — keep nothing.
	if strings.MaskMiddle("secret", 0, 0, 42) == "******" { pass = pass + 1 }

	// MaskMiddle — keep half.
	if strings.MaskMiddle("abcdefgh", 2, 2, 35) == "ab####gh" { pass = pass + 1 }     // '#' = 35

	// MaskMiddle — keep more than len returns unchanged.
	if strings.MaskMiddle("abc", 5, 5, 42) == "abc" { pass = pass + 1 }
	if strings.MaskMiddle("abc", 2, 1, 42) == "abc" { pass = pass + 1 }

	// MaskMiddle — exact-fit boundary (keepStart + keepEnd == len).
	if strings.MaskMiddle("abcd", 2, 2, 42) == "abcd" { pass = pass + 1 }

	// MaskMiddle — negative clamps to 0.
	if strings.MaskMiddle("hello", -1, -1, 42) == "*****" { pass = pass + 1 }

	// MaskMiddle — empty.
	if strings.MaskMiddle("", 2, 2, 42) == "" { pass = pass + 1 }

	// MaskMiddle — credit card style.
	if strings.MaskMiddle("4111111111111111", 4, 4, 42) == "4111********1111" { pass = pass + 1 }

	// MaskMiddle — email-like (first char + domain).
	if strings.MaskMiddle("alice@example.com", 1, 12, 42) == "a****@example.com" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 18 { ret 42 }
	ret 0
}
