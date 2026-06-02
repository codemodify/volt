package main
import "log"
import "path/filepath"

// Positive test: filepath.WithName + filepath.IsHidden.

fun main() int {
	var pass int = 0

	// WithName — preserves directory.
	if filepath.WithName("/path/to/file.txt", "other.md") == "/path/to/other.md" { pass = pass + 1 }
	if filepath.WithName("src/main.c", "main.o") == "src/main.o" { pass = pass + 1 }

	// WithName — no directory.
	if filepath.WithName("foo.txt", "bar.md") == "bar.md" { pass = pass + 1 }
	if filepath.WithName("Makefile", "x") == "x" { pass = pass + 1 }

	// WithName — empty path.
	if filepath.WithName("", "x") == "x" { pass = pass + 1 }

	// WithName — empty name strips basename.
	if filepath.WithName("/a/b/c.txt", "") == "/a/b/" { pass = pass + 1 }

	// WithName — root.
	if filepath.WithName("/file.txt", "other.txt") == "/other.txt" { pass = pass + 1 }

	// WithName — multi-segment with deep nesting.
	if filepath.WithName("/a/b/c/d/leaf", "newleaf") == "/a/b/c/d/newleaf" { pass = pass + 1 }

	// IsHidden — leading-dot basenames.
	if filepath.IsHidden(".bashrc") { pass = pass + 1 }
	if filepath.IsHidden("/etc/.config") { pass = pass + 1 }
	if filepath.IsHidden("/home/user/.cache") { pass = pass + 1 }

	// IsHidden — non-hidden.
	if !filepath.IsHidden("foo.txt") { pass = pass + 1 }
	if !filepath.IsHidden("/path/foo") { pass = pass + 1 }
	if !filepath.IsHidden("Makefile") { pass = pass + 1 }

	// IsHidden — corner cases.
	if filepath.IsHidden(".") { pass = pass + 1 }
	if filepath.IsHidden("..") { pass = pass + 1 }

	// IsHidden — dot in middle of name doesn't count.
	if !filepath.IsHidden("a.b.c") { pass = pass + 1 }
	if !filepath.IsHidden("/path/a.b.c") { pass = pass + 1 }

	// IsHidden — empty (Base returns ".").
	if filepath.IsHidden("") { pass = pass + 1 }

	// IsHidden — trailing slash strips before check.
	if filepath.IsHidden("/path/to/.hidden/") { pass = pass + 1 }

	// Roundtrip: WithName + Base recovers the new name.
	if filepath.Base(filepath.WithName("/dir/old.txt", "new.md")) == "new.md" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 21 { ret 42 }
	ret 0
}
