package main
import "log"
import "strings"

// Positive test: strings.IndexFunc / LastIndexFunc / TrimFunc —
// Go-style predicate-based byte operations. Each takes a first-class
// `fun(byte) bool` predicate.

fun isDigit(b byte) bool {
	if b >= 48 {
		if b <= 57 { ret true }
	}
	ret false
}

fun isWs(b byte) bool {
	if b == 32 { ret true }
	if b == 9 { ret true }
	if b == 10 { ret true }
	ret false
}

fun main() int {
	var pass int = 0

	// IndexFunc: first digit.
	if strings.IndexFunc("abc123", isDigit) == 3 { pass = pass + 1 }
	// No match.
	if strings.IndexFunc("hello", isDigit) == -1 { pass = pass + 1 }
	// Match at index 0.
	if strings.IndexFunc("9live", isDigit) == 0 { pass = pass + 1 }
	// Empty input.
	if strings.IndexFunc("", isDigit) == -1 { pass = pass + 1 }

	// LastIndexFunc: last digit.
	if strings.LastIndexFunc("abc123x", isDigit) == 5 { pass = pass + 1 }
	if strings.LastIndexFunc("hello", isDigit) == -1 { pass = pass + 1 }
	// Single match at end.
	if strings.LastIndexFunc("abc1", isDigit) == 3 { pass = pass + 1 }

	// TrimFunc: strip whitespace (leading + trailing).
	var r1 string = strings.TrimFunc("  \thello  \n", isWs)
	if r1 == "hello" { pass = pass + 1 }
	// All-whitespace → empty.
	var r2 string = strings.TrimFunc("   \t\n", isWs)
	if r2 == "" { pass = pass + 1 }
	// No leading/trailing match → unchanged.
	var r3 string = strings.TrimFunc("solid", isWs)
	if r3 == "solid" { pass = pass + 1 }
	// Strip digits from both sides.
	var r4 string = strings.TrimFunc("123abc456", isDigit)
	if r4 == "abc" { pass = pass + 1 }

	log.Println("pass=%d r1=%s r4=%s", pass, r1, r4)
	if pass == 11 { ret 42 }
	ret 0
}
