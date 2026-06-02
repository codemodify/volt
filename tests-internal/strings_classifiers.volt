package main
import "log"
import "strings"

// Positive test: strings.IsNumeric + IsAlpha + IsAlphanumeric.

fun main() int {
	var pass int = 0

	// IsNumeric.
	if strings.IsNumeric("0") { pass = pass + 1 }
	if strings.IsNumeric("9") { pass = pass + 1 }
	if strings.IsNumeric("12345") { pass = pass + 1 }
	if !strings.IsNumeric("12a") { pass = pass + 1 }
	if !strings.IsNumeric("-1") { pass = pass + 1 }   // '-' not a digit
	if !strings.IsNumeric("1.0") { pass = pass + 1 }
	if !strings.IsNumeric("") { pass = pass + 1 }
	if !strings.IsNumeric("a") { pass = pass + 1 }
	if !strings.IsNumeric(" 1") { pass = pass + 1 }    // leading space

	// IsAlpha.
	if strings.IsAlpha("a") { pass = pass + 1 }
	if strings.IsAlpha("Z") { pass = pass + 1 }
	if strings.IsAlpha("Hello") { pass = pass + 1 }
	if strings.IsAlpha("ABCdef") { pass = pass + 1 }
	if !strings.IsAlpha("abc1") { pass = pass + 1 }
	if !strings.IsAlpha("ab c") { pass = pass + 1 }
	if !strings.IsAlpha("") { pass = pass + 1 }
	if !strings.IsAlpha("123") { pass = pass + 1 }
	if !strings.IsAlpha("a!b") { pass = pass + 1 }

	// IsAlphanumeric.
	if strings.IsAlphanumeric("abc") { pass = pass + 1 }
	if strings.IsAlphanumeric("ABC") { pass = pass + 1 }
	if strings.IsAlphanumeric("123") { pass = pass + 1 }
	if strings.IsAlphanumeric("abc123") { pass = pass + 1 }
	if strings.IsAlphanumeric("A1b2C3") { pass = pass + 1 }
	if !strings.IsAlphanumeric("abc!") { pass = pass + 1 }
	if !strings.IsAlphanumeric("a b") { pass = pass + 1 }
	if !strings.IsAlphanumeric("") { pass = pass + 1 }
	if !strings.IsAlphanumeric("a-b") { pass = pass + 1 }
	if !strings.IsAlphanumeric("a.b") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 28 { ret 42 }
	ret 0
}
