package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty s → true (vacuous).
	if strings.HasNone("", "abc") { pass = pass + 1 }

	// Both empty → true.
	if strings.HasNone("", "") { pass = pass + 1 }

	// Empty chars + non-empty s → true (nothing forbidden).
	if strings.HasNone("abc", "") { pass = pass + 1 }

	// No overlap → true.
	if strings.HasNone("abc", "def") { pass = pass + 1 }
	if strings.HasNone("hello", "0123456789") { pass = pass + 1 }

	// Any overlap → false.
	if !strings.HasNone("abc", "xyzc") { pass = pass + 1 }
	if !strings.HasNone("abc", "a") { pass = pass + 1 }

	// Repeated chars in blacklist don't change result.
	if !strings.HasNone("abc", "aabbcc") { pass = pass + 1 }

	// Control-char sanitizer use case: no newlines / CR / tabs.
	if strings.HasNone("hello world", "\n\r\t") { pass = pass + 1 }
	if !strings.HasNone("hello\nworld", "\n\r\t") { pass = pass + 1 }

	// Log-injection screen: no semicolons / quotes.
	if strings.HasNone("safe input", ";\"'") { pass = pass + 1 }
	if !strings.HasNone("not; safe", ";\"'") { pass = pass + 1 }

	// HasNone is the complement of ContainsAny (modulo empty inputs).
	if strings.HasNone("clean", "@#$") == !strings.ContainsAny("clean", "@#$") { pass = pass + 1 }
	if strings.HasNone("dir@ty", "@#$") == !strings.ContainsAny("dir@ty", "@#$") { pass = pass + 1 }

	// Single-char self-blacklist.
	if !strings.HasNone("a", "a") { pass = pass + 1 }
	if strings.HasNone("a", "b") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
