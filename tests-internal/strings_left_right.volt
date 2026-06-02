package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty.
	if strings.Left("", 5) == "" { pass = pass + 1 }
	if strings.Right("", 5) == "" { pass = pass + 1 }

	// n <= 0 → "".
	if strings.Left("hello", 0) == "" { pass = pass + 1 }
	if strings.Left("hello", -3) == "" { pass = pass + 1 }
	if strings.Right("hello", 0) == "" { pass = pass + 1 }
	if strings.Right("hello", -3) == "" { pass = pass + 1 }

	// Take prefix.
	if strings.Left("hello world", 5) == "hello" { pass = pass + 1 }
	if strings.Left("hello", 1) == "h" { pass = pass + 1 }
	if strings.Left("hello", 3) == "hel" { pass = pass + 1 }

	// Take suffix.
	if strings.Right("hello world", 5) == "world" { pass = pass + 1 }
	if strings.Right("hello", 1) == "o" { pass = pass + 1 }
	if strings.Right("hello", 3) == "llo" { pass = pass + 1 }

	// n >= len → whole string.
	if strings.Left("hi", 100) == "hi" { pass = pass + 1 }
	if strings.Left("hi", 2) == "hi" { pass = pass + 1 }
	if strings.Right("hi", 100) == "hi" { pass = pass + 1 }
	if strings.Right("hi", 2) == "hi" { pass = pass + 1 }

	// Single-byte string.
	if strings.Left("a", 1) == "a" { pass = pass + 1 }
	if strings.Right("a", 1) == "a" { pass = pass + 1 }

	// Cross-property: Left(s,n) + Right(s, len-n) == s for valid n.
	var lhs string = strings.Left("hello world", 5)
	var rhs string = strings.Right("hello world", 6)
	if lhs + rhs == "hello world" { pass = pass + 1 }

	// Use case: file extension (last 4 chars).
	if strings.Right("config.json", 5) == ".json" { pass = pass + 1 }
	if strings.Right("readme.md", 3) == ".md" { pass = pass + 1 }

	// Use case: log line prefix (first 19 chars = ISO-8601 datetime).
	var logl string = "2026-05-28 12:00:00 INFO server started"
	if strings.Left(logl, 19) == "2026-05-28 12:00:00" { pass = pass + 1 }

	// Use case: token preview / masking.
	var token string = "abc123def456ghi789"
	var preview string = strings.Left(token, 4) + "..." + strings.Right(token, 4)
	if preview == "abc1...i789" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
