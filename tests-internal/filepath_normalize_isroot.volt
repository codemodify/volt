package main
import "log"
import "path/filepath"

// Positive test: filepath.NormalizeSlashes + filepath.IsRoot.

fun main() int {
	var pass int = 0

	// NormalizeSlashes — basic collapse.
	if filepath.NormalizeSlashes("//a///b") == "/a/b" { pass = pass + 1 }
	if filepath.NormalizeSlashes("a//b") == "a/b" { pass = pass + 1 }
	if filepath.NormalizeSlashes("//a///b//") == "/a/b/" { pass = pass + 1 }

	// Empty / single slash.
	if filepath.NormalizeSlashes("") == "" { pass = pass + 1 }
	if filepath.NormalizeSlashes("/") == "/" { pass = pass + 1 }
	if filepath.NormalizeSlashes("///") == "/" { pass = pass + 1 }

	// Path with no slashes returns unchanged.
	if filepath.NormalizeSlashes("foo") == "foo" { pass = pass + 1 }
	if filepath.NormalizeSlashes("Makefile") == "Makefile" { pass = pass + 1 }

	// Single trailing slash preserved.
	if filepath.NormalizeSlashes("a/") == "a/" { pass = pass + 1 }
	if filepath.NormalizeSlashes("a//") == "a/" { pass = pass + 1 }

	// Relative collapse.
	if filepath.NormalizeSlashes("foo//bar///baz") == "foo/bar/baz" { pass = pass + 1 }

	// Absolute collapse.
	if filepath.NormalizeSlashes("/usr//local///bin") == "/usr/local/bin" { pass = pass + 1 }

	// IsRoot — basic.
	if filepath.IsRoot("/") { pass = pass + 1 }
	if filepath.IsRoot("//") { pass = pass + 1 }
	if filepath.IsRoot("///") { pass = pass + 1 }

	// IsRoot — not root.
	if !filepath.IsRoot("") { pass = pass + 1 }
	if !filepath.IsRoot("/a") { pass = pass + 1 }
	if !filepath.IsRoot("a") { pass = pass + 1 }
	if !filepath.IsRoot("/usr") { pass = pass + 1 }

	// Identity: NormalizeSlashes(any-root) == "/".
	if filepath.NormalizeSlashes("////") == "/" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
