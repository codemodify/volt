package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// Empty s → "".
	if strings.KeepOnly("", "abc") == "" { pass = pass + 1 }

	// Empty chars → "" (nothing allowed).
	if strings.KeepOnly("hello", "") == "" { pass = pass + 1 }

	// Both empty → "".
	if strings.KeepOnly("", "") == "" { pass = pass + 1 }

	// Drop disallowed bytes; keep allowed.
	if strings.KeepOnly("hello world", "abcdefghijklmnopqrstuvwxyz") == "helloworld" { pass = pass + 1 }
	if strings.KeepOnly("a1b2c3", "abc") == "abc" { pass = pass + 1 }
	if strings.KeepOnly("a1b2c3", "0123456789") == "123" { pass = pass + 1 }

	// Order is preserved (filter, not sort).
	if strings.KeepOnly("c1b2a3", "abc") == "cba" { pass = pass + 1 }

	// All bytes allowed → unchanged content.
	if strings.KeepOnly("abc", "abcd") == "abc" { pass = pass + 1 }
	if strings.KeepOnly("abc", "abc") == "abc" { pass = pass + 1 }

	// All bytes disallowed → "".
	if strings.KeepOnly("xyz", "abc") == "" { pass = pass + 1 }

	// Digits-only filter.
	if strings.KeepOnly("phone: (555) 123-4567", "0123456789") == "5551234567" { pass = pass + 1 }

	// Hex-only filter.
	if strings.KeepOnly("0xDEADBEEF.txt", "0123456789abcdefABCDEFx") == "0xDEADBEEFx" { pass = pass + 1 }

	// Repeated chars in alphabet don't change result.
	if strings.KeepOnly("hello", "aabbeellloo") == "ello" { pass = pass + 1 }

	// Cross-property with HasOnly.
	if strings.HasOnly(strings.KeepOnly("a1b2c3", "abc"), "abc") { pass = pass + 1 }
	if strings.HasOnly(strings.KeepOnly("hello world!@#", "abcdefghijklmnopqrstuvwxyz"), "abcdefghijklmnopqrstuvwxyz") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 15 { ret 42 }
	ret 0
}
