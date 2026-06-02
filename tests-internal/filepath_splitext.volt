package main
import "log"
import "path/filepath"

// Positive test: filepath.SplitExt.

fun main() int {
	var pass int = 0

	var base string = ""
	var ext string = ""

	// Simple file with extension.
	base, ext = filepath.SplitExt("foo.txt")
	if base == "foo" { pass = pass + 1 }
	if ext == ".txt" { pass = pass + 1 }

	// Multi-segment with extension.
	base, ext = filepath.SplitExt("/path/to/file.go")
	if base == "/path/to/file" { pass = pass + 1 }
	if ext == ".go" { pass = pass + 1 }

	// Multiple dots — only LAST is the extension.
	base, ext = filepath.SplitExt("archive.tar.gz")
	if base == "archive.tar" { pass = pass + 1 }
	if ext == ".gz" { pass = pass + 1 }

	// No extension.
	base, ext = filepath.SplitExt("Makefile")
	if base == "Makefile" { pass = pass + 1 }
	if ext == "" { pass = pass + 1 }

	// Hidden file (leading-dot basename, no extension).
	base, ext = filepath.SplitExt(".bashrc")
	if base == ".bashrc" { pass = pass + 1 }
	if ext == "" { pass = pass + 1 }

	// Hidden file in directory.
	base, ext = filepath.SplitExt("/home/u/.bashrc")
	if base == "/home/u/.bashrc" { pass = pass + 1 }
	if ext == "" { pass = pass + 1 }

	// Hidden file with extension after it ("config.local").
	base, ext = filepath.SplitExt(".config.local")
	if base == ".config" { pass = pass + 1 }
	if ext == ".local" { pass = pass + 1 }

	// Dot in directory only.
	base, ext = filepath.SplitExt("/a.b/c")
	if base == "/a.b/c" { pass = pass + 1 }
	if ext == "" { pass = pass + 1 }

	// Trailing dot.
	base, ext = filepath.SplitExt("foo.")
	if base == "foo" { pass = pass + 1 }
	if ext == "." { pass = pass + 1 }

	// Empty input.
	base, ext = filepath.SplitExt("")
	if base == "" { pass = pass + 1 }
	if ext == "" { pass = pass + 1 }

	// Just dot.
	base, ext = filepath.SplitExt(".")
	if base == "." { pass = pass + 1 }
	if ext == "" { pass = pass + 1 }

	// Re-compose: base + ext should equal path for normal files.
	base, ext = filepath.SplitExt("/x/y/z.txt")
	if (base + ext) == "/x/y/z.txt" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 23 { ret 42 }
	ret 0
}
