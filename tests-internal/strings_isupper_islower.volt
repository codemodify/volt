package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// IsUpper — basic.
	if strings.IsUpper("HELLO") { pass = pass + 1 }
	if !strings.IsUpper("hello") { pass = pass + 1 }
	if !strings.IsUpper("Hello") { pass = pass + 1 }

	// IsUpper — non-letter chars are neutral.
	if strings.IsUpper("HELLO WORLD") { pass = pass + 1 }
	if strings.IsUpper("HELLO 123") { pass = pass + 1 }
	if strings.IsUpper("ABC!") { pass = pass + 1 }
	if strings.IsUpper("HELLO_WORLD") { pass = pass + 1 }

	// IsUpper — single char.
	if strings.IsUpper("A") { pass = pass + 1 }
	if !strings.IsUpper("a") { pass = pass + 1 }

	// IsUpper — empty / no-letter inputs return false.
	if !strings.IsUpper("") { pass = pass + 1 }
	if !strings.IsUpper("123") { pass = pass + 1 }
	if !strings.IsUpper(" ") { pass = pass + 1 }

	// IsUpper — single lowercase letter disqualifies.
	if !strings.IsUpper("AbC") { pass = pass + 1 }

	// IsLower — basic.
	if strings.IsLower("hello") { pass = pass + 1 }
	if !strings.IsLower("HELLO") { pass = pass + 1 }
	if !strings.IsLower("Hello") { pass = pass + 1 }

	// IsLower — non-letter chars are neutral.
	if strings.IsLower("hello world") { pass = pass + 1 }
	if strings.IsLower("abc 123") { pass = pass + 1 }
	if strings.IsLower("hello!") { pass = pass + 1 }

	// IsLower — single char.
	if strings.IsLower("a") { pass = pass + 1 }
	if !strings.IsLower("A") { pass = pass + 1 }

	// IsLower — empty / no-letter inputs.
	if !strings.IsLower("") { pass = pass + 1 }
	if !strings.IsLower("123") { pass = pass + 1 }
	if !strings.IsLower(" ") { pass = pass + 1 }

	// Mutually exclusive on mixed-case.
	if !strings.IsUpper("Abc") { pass = pass + 1 }
	if !strings.IsLower("Abc") { pass = pass + 1 }

	// Constants pattern: "MAX_SIZE" is upper, "max_size" is lower.
	if strings.IsUpper("MAX_SIZE") { pass = pass + 1 }
	if strings.IsLower("max_size") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 28 { ret 42 }
	ret 0
}
