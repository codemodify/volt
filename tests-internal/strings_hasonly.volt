package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty s → true (vacuous).
	if strings.HasOnly("", "abc") { pass = pass + 1 }

	// Both empty → true.
	if strings.HasOnly("", "") { pass = pass + 1 }

	// Empty chars + non-empty s → false.
	if !strings.HasOnly("a", "") { pass = pass + 1 }

	// All bytes in alphabet.
	if strings.HasOnly("abc", "abcd") { pass = pass + 1 }
	if strings.HasOnly("aaa", "a") { pass = pass + 1 }

	// One byte outside alphabet.
	if !strings.HasOnly("abcd", "abc") { pass = pass + 1 }
	if !strings.HasOnly("axc", "abc") { pass = pass + 1 }

	// Repeated chars in alphabet don't affect membership.
	if strings.HasOnly("abc", "aabbcc") { pass = pass + 1 }

	// Digits-only whitelist.
	if strings.HasOnly("12345", "0123456789") { pass = pass + 1 }
	if !strings.HasOnly("12a45", "0123456789") { pass = pass + 1 }

	// Alpha-only whitelist.
	if strings.HasOnly("hello", "abcdefghijklmnopqrstuvwxyz") { pass = pass + 1 }
	if !strings.HasOnly("hello1", "abcdefghijklmnopqrstuvwxyz") { pass = pass + 1 }

	// Hex digit whitelist.
	if strings.HasOnly("deadbeef", "0123456789abcdef") { pass = pass + 1 }
	if !strings.HasOnly("deadbeeg", "0123456789abcdef") { pass = pass + 1 }

	// Single-char self-membership.
	if strings.HasOnly("a", "a") { pass = pass + 1 }
	if !strings.HasOnly("a", "b") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
