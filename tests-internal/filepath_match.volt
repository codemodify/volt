package main
import "log"
import "path/filepath"

// Positive test: filepath.Match — glob matching with `*` and `?`
// wildcards. Character classes are not yet supported (v1).

fun main() int {
	var pass int = 0

	// Literal match.
	if filepath.Match("foo", "foo") { pass = pass + 1 }
	if !filepath.Match("foo", "bar") { pass = pass + 1 }
	if !filepath.Match("foo", "foox") { pass = pass + 1 }

	// `?` matches single byte.
	if filepath.Match("f?o", "foo") { pass = pass + 1 }
	if filepath.Match("f?o", "fxo") { pass = pass + 1 }
	if !filepath.Match("f?o", "foox") { pass = pass + 1 }
	if !filepath.Match("f?o", "fo") { pass = pass + 1 }

	// `*` matches any sequence (no slash).
	if filepath.Match("*.go", "main.go") { pass = pass + 1 }
	if filepath.Match("*.go", ".go") { pass = pass + 1 }
	if !filepath.Match("*.go", "main.go.bak") { pass = pass + 1 }
	if filepath.Match("a*b", "ab") { pass = pass + 1 }
	if filepath.Match("a*b", "axxxb") { pass = pass + 1 }
	if !filepath.Match("a*b", "ax/yb") { pass = pass + 1 }   // '*' shouldn't cross '/'

	// Multiple wildcards.
	if filepath.Match("*foo*", "barfoobaz") { pass = pass + 1 }
	if filepath.Match("*.*", "a.b.c") { pass = pass + 1 }

	// Empty pattern matches empty name.
	if filepath.Match("", "") { pass = pass + 1 }
	if !filepath.Match("", "x") { pass = pass + 1 }

	// `*` matches empty.
	if filepath.Match("*", "") { pass = pass + 1 }

	// Trailing slash protection: `*.txt` doesn't match `dir/file.txt`
	// (Go semantics — Match doesn't span path separators).
	if !filepath.Match("*.txt", "dir/file.txt") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 19 { ret 42 }
	ret 0
}
