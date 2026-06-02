package main
import "log"
import "strings"

// Positive test: strings.Capitalize + strings.Reverse.

fun main() int {
	var pass int = 0

	// Capitalize.
	if strings.Capitalize("hello") == "Hello" { pass = pass + 1 }
	if strings.Capitalize("Hello") == "Hello" { pass = pass + 1 }   // already upper
	if strings.Capitalize("hello world") == "Hello world" { pass = pass + 1 }   // only first
	if strings.Capitalize("a") == "A" { pass = pass + 1 }
	if strings.Capitalize("") == "" { pass = pass + 1 }
	if strings.Capitalize("123abc") == "123abc" { pass = pass + 1 }   // not a letter
	if strings.Capitalize("z") == "Z" { pass = pass + 1 }

	// Reverse.
	if strings.Reverse("abc") == "cba" { pass = pass + 1 }
	if strings.Reverse("") == "" { pass = pass + 1 }
	if strings.Reverse("a") == "a" { pass = pass + 1 }
	if strings.Reverse("Hello, World!") == "!dlroW ,olleH" { pass = pass + 1 }
	if strings.Reverse("abba") == "abba" { pass = pass + 1 }   // palindrome
	// Reverse-of-reverse round-trip.
	var s string = "abcdef"
	var r1 string = strings.Reverse(s)
	var r2 string = strings.Reverse(r1)
	if r2 == "abcdef" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 13 { ret 42 }
	ret 0
}
