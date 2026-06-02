package main
import "log"
import "strings"

// Positive test: strings.EnsurePrefix + strings.EnsureSuffix.

fun main() int {
	var pass int = 0

	// EnsurePrefix — prefix missing → prepend.
	if strings.EnsurePrefix("example.com", "https://") == "https://example.com" { pass = pass + 1 }
	if strings.EnsurePrefix("path/to/file", "/") == "/path/to/file" { pass = pass + 1 }

	// EnsurePrefix — prefix already present → unchanged.
	if strings.EnsurePrefix("https://example.com", "https://") == "https://example.com" { pass = pass + 1 }
	if strings.EnsurePrefix("/usr/bin", "/") == "/usr/bin" { pass = pass + 1 }

	// EnsurePrefix — empty prefix is always present → unchanged.
	if strings.EnsurePrefix("foo", "") == "foo" { pass = pass + 1 }

	// EnsurePrefix — empty s with non-empty prefix → just prefix.
	if strings.EnsurePrefix("", "x") == "x" { pass = pass + 1 }

	// EnsurePrefix — exact match.
	if strings.EnsurePrefix("https://", "https://") == "https://" { pass = pass + 1 }

	// EnsurePrefix — prefix longer than s, no match → prepend.
	if strings.EnsurePrefix("foo", "prefix-") == "prefix-foo" { pass = pass + 1 }

	// EnsureSuffix — suffix missing → append.
	if strings.EnsureSuffix("file", ".txt") == "file.txt" { pass = pass + 1 }
	if strings.EnsureSuffix("dir", "/") == "dir/" { pass = pass + 1 }

	// EnsureSuffix — suffix already present → unchanged.
	if strings.EnsureSuffix("file.txt", ".txt") == "file.txt" { pass = pass + 1 }
	if strings.EnsureSuffix("dir/", "/") == "dir/" { pass = pass + 1 }

	// EnsureSuffix — empty suffix is always present.
	if strings.EnsureSuffix("foo", "") == "foo" { pass = pass + 1 }

	// EnsureSuffix — empty s.
	if strings.EnsureSuffix("", "x") == "x" { pass = pass + 1 }

	// EnsureSuffix — line-ending normalization.
	if strings.EnsureSuffix("hello", "\n") == "hello\n" { pass = pass + 1 }
	if strings.EnsureSuffix("hello\n", "\n") == "hello\n" { pass = pass + 1 }

	// Idempotence: EnsurePrefix(EnsurePrefix(s, p), p) == EnsurePrefix(s, p).
	if strings.EnsurePrefix(strings.EnsurePrefix("foo", "x-"), "x-") == strings.EnsurePrefix("foo", "x-") { pass = pass + 1 }

	// Idempotence: EnsureSuffix(EnsureSuffix(s, sx), sx) == EnsureSuffix(s, sx).
	if strings.EnsureSuffix(strings.EnsureSuffix("foo", "-y"), "-y") == strings.EnsureSuffix("foo", "-y") { pass = pass + 1 }

	// TrimPrefix∘EnsurePrefix == TrimPrefix.
	if strings.TrimPrefix(strings.EnsurePrefix("foo", "x-"), "x-") == "foo" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
