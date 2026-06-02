package main
import "log"
import "strings"

// Positive test: strings.ContainsAny + strings.Map. Map takes a
// first-class function value (closure) that transforms each byte.

fun rot13(b byte) byte {
	// Lowercase a-z: shift by 13 (mod 26)
	if b >= 97 {
		if b <= 122 {
			ret 97 + ((b - 97 + 13) % 26)
		}
	}
	// Uppercase A-Z
	if b >= 65 {
		if b <= 90 {
			ret 65 + ((b - 65 + 13) % 26)
		}
	}
	ret b
}

fun upper(b byte) byte {
	if b >= 97 {
		if b <= 122 {
			ret b - 32
		}
	}
	ret b
}

fun main() int {
	var pass int = 0

	// ContainsAny: at least one match.
	if strings.ContainsAny("hello world", "aeiou") { pass = pass + 1 }
	// No match.
	if !strings.ContainsAny("xyz", "aeiou") { pass = pass + 1 }
	// Empty chars → false.
	if !strings.ContainsAny("hello", "") { pass = pass + 1 }
	// Empty s → false (no bytes to scan).
	if !strings.ContainsAny("", "abc") { pass = pass + 1 }
	// Single-byte match in s.
	if strings.ContainsAny("x", "axb") { pass = pass + 1 }

	// Map with ROT13 closure.
	var r1 string = strings.Map(rot13, "hello")
	if r1 == "uryyb" { pass = pass + 1 }
	var r2 string = strings.Map(rot13, "uryyb")
	if r2 == "hello" { pass = pass + 1 }
	// Non-letter bytes pass through unchanged.
	var r3 string = strings.Map(rot13, "Hello, World!")
	if r3 == "Uryyb, Jbeyq!" { pass = pass + 1 }
	// Empty input.
	var r4 string = strings.Map(rot13, "")
	if r4 == "" { pass = pass + 1 }

	// Map with custom upper-caser.
	var r5 string = strings.Map(upper, "shout")
	if r5 == "SHOUT" { pass = pass + 1 }

	log.Println("pass=%d r1=%s r3=%s", pass, r1, r3)
	if pass == 10 { ret 42 }
	ret 0
}
