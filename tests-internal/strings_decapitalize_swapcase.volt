package main
import "log"
import "strings"

// Positive test: strings.Decapitalize + strings.SwapCase.

fun main() int {
	var pass int = 0

	// Decapitalize basic.
	if strings.Decapitalize("Hello") == "hello" { pass = pass + 1 }
	if strings.Decapitalize("WORLD") == "wORLD" { pass = pass + 1 }   // only first byte lowered
	if strings.Decapitalize("camelCase") == "camelCase" { pass = pass + 1 }   // already lower
	if strings.Decapitalize("X") == "x" { pass = pass + 1 }

	// Single char.
	if strings.Decapitalize("a") == "a" { pass = pass + 1 }   // already lower

	// Non-letter prefix unchanged.
	if strings.Decapitalize("1Hello") == "1Hello" { pass = pass + 1 }
	if strings.Decapitalize("!Foo") == "!Foo" { pass = pass + 1 }

	// Empty.
	if strings.Decapitalize("") == "" { pass = pass + 1 }

	// CapsCase → camelCase pattern.
	if strings.Decapitalize("MyClassName") == "myClassName" { pass = pass + 1 }

	// SwapCase basic.
	if strings.SwapCase("Hello") == "hELLO" { pass = pass + 1 }
	if strings.SwapCase("WORLD") == "world" { pass = pass + 1 }
	if strings.SwapCase("hello") == "HELLO" { pass = pass + 1 }

	// Mixed with non-letters.
	if strings.SwapCase("Hello, World!") == "hELLO, wORLD!" { pass = pass + 1 }
	if strings.SwapCase("abc123XYZ") == "ABC123xyz" { pass = pass + 1 }

	// Empty.
	if strings.SwapCase("") == "" { pass = pass + 1 }

	// All non-letters.
	if strings.SwapCase("12345 !@#") == "12345 !@#" { pass = pass + 1 }

	// Single char.
	if strings.SwapCase("a") == "A" { pass = pass + 1 }
	if strings.SwapCase("Z") == "z" { pass = pass + 1 }
	if strings.SwapCase("5") == "5" { pass = pass + 1 }

	// Idempotent: SwapCase twice = original.
	var orig string = "Hello, World!"
	if strings.SwapCase(strings.SwapCase(orig)) == orig { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
