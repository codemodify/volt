package main
import "log"
import "path/filepath"

// Positive test: filepath.WithoutExt + filepath.WithExt.

fun main() int {
	var pass int = 0

	// WithoutExt — simple file.
	if filepath.WithoutExt("foo.txt") == "foo" { pass = pass + 1 }

	// WithoutExt — full path.
	if filepath.WithoutExt("/path/to/file.go") == "/path/to/file" { pass = pass + 1 }

	// WithoutExt — multi-extension only strips final.
	if filepath.WithoutExt("archive.tar.gz") == "archive.tar" { pass = pass + 1 }

	// WithoutExt — no extension returns unchanged.
	if filepath.WithoutExt("Makefile") == "Makefile" { pass = pass + 1 }

	// WithoutExt — hidden file (leading-dot basename) returns unchanged.
	if filepath.WithoutExt(".bashrc") == ".bashrc" { pass = pass + 1 }

	// WithoutExt — empty.
	if filepath.WithoutExt("") == "" { pass = pass + 1 }

	// WithExt — leading-dot ext.
	if filepath.WithExt("foo.txt", ".md") == "foo.md" { pass = pass + 1 }

	// WithExt — no-dot ext (auto-prepend).
	if filepath.WithExt("foo.txt", "md") == "foo.md" { pass = pass + 1 }

	// WithExt — append when path has no extension.
	if filepath.WithExt("Makefile", "txt") == "Makefile.txt" { pass = pass + 1 }
	if filepath.WithExt("Makefile", ".txt") == "Makefile.txt" { pass = pass + 1 }

	// WithExt — strip when ext is empty.
	if filepath.WithExt("foo.txt", "") == "foo" { pass = pass + 1 }

	// WithExt — multi-extension only replaces final.
	if filepath.WithExt("archive.tar.gz", "bz2") == "archive.tar.bz2" { pass = pass + 1 }
	if filepath.WithExt("archive.tar.gz", ".bz2") == "archive.tar.bz2" { pass = pass + 1 }

	// WithExt — full path with directory preserved.
	if filepath.WithExt("/path/to/file.go", ".cpp") == "/path/to/file.cpp" { pass = pass + 1 }

	// WithExt — hidden file (no extension to replace, append instead).
	if filepath.WithExt(".bashrc", "bak") == ".bashrc.bak" { pass = pass + 1 }

	// Build-pipeline example: .c → .o
	if filepath.WithExt("src/main.c", ".o") == "src/main.o" { pass = pass + 1 }

	// Roundtrip: WithExt(WithoutExt(p) + ext) preserves WithExt(p, ext).
	if filepath.WithExt("foo.txt", ".md") == filepath.WithExt(filepath.WithoutExt("foo.txt"), ".md") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
