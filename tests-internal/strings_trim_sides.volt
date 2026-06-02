package main
import "log"
import "strings"

// Positive test: strings.TrimLeft + strings.TrimRight.

fun main() int {
	var pass int = 0

	// TrimLeft basic.
	if strings.TrimLeft("  hello  ", " ") == "hello  " { pass = pass + 1 }
	// TrimLeft with multi-byte cutset.
	if strings.TrimLeft("xxxabc", "x") == "abc" { pass = pass + 1 }
	// TrimLeft no leading match.
	if strings.TrimLeft("hello ", " ") == "hello " { pass = pass + 1 }
	// TrimLeft all match — empty result.
	if strings.TrimLeft("xxxx", "x") == "" { pass = pass + 1 }
	// TrimLeft empty cutset → unchanged.
	if strings.TrimLeft(" abc ", "") == " abc " { pass = pass + 1 }
	// TrimLeft empty input.
	if strings.TrimLeft("", " ") == "" { pass = pass + 1 }
	// TrimLeft mixed cutset.
	if strings.TrimLeft("0123abc", "0123") == "abc" { pass = pass + 1 }

	// TrimRight basic.
	if strings.TrimRight("  hello  ", " ") == "  hello" { pass = pass + 1 }
	// TrimRight multi-byte cutset.
	if strings.TrimRight("abcxxx", "x") == "abc" { pass = pass + 1 }
	// TrimRight no trailing match.
	if strings.TrimRight(" hello", " ") == " hello" { pass = pass + 1 }
	// TrimRight all match.
	if strings.TrimRight("xxxx", "x") == "" { pass = pass + 1 }
	// TrimRight empty cutset.
	if strings.TrimRight(" abc ", "") == " abc " { pass = pass + 1 }
	// TrimRight empty input.
	if strings.TrimRight("", " ") == "" { pass = pass + 1 }
	// TrimRight mixed cutset.
	if strings.TrimRight("abc0123", "0123") == "abc" { pass = pass + 1 }

	// Combined: TrimLeft + TrimRight is equivalent to Trim.
	var t1 string = strings.TrimRight(strings.TrimLeft("---hi---", "-"), "-")
	if t1 == "hi" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
