package main
import "log"
import "path/filepath"

// Positive test: filepath.HeadN + filepath.TailN.

fun main() int {
	var pass int = 0

	// HeadN — absolute path, n=2.
	if filepath.HeadN("/a/b/c/d", 2) == "/a/b" { pass = pass + 1 }

	// HeadN — absolute, n=1.
	if filepath.HeadN("/a/b/c", 1) == "/a" { pass = pass + 1 }

	// HeadN — absolute, n=0 → just root.
	if filepath.HeadN("/a/b/c", 0) == "/" { pass = pass + 1 }

	// HeadN — relative path.
	if filepath.HeadN("a/b/c", 2) == "a/b" { pass = pass + 1 }

	// HeadN — relative, n=0.
	if filepath.HeadN("a/b/c", 0) == "" { pass = pass + 1 }

	// HeadN — n > component count returns full path.
	if filepath.HeadN("/a/b", 10) == "/a/b" { pass = pass + 1 }
	if filepath.HeadN("a/b", 10) == "a/b" { pass = pass + 1 }

	// HeadN — empty path.
	if filepath.HeadN("", 5) == "" { pass = pass + 1 }

	// HeadN — single component.
	if filepath.HeadN("foo", 1) == "foo" { pass = pass + 1 }
	if filepath.HeadN("/foo", 1) == "/foo" { pass = pass + 1 }

	// TailN — absolute path, n=2.
	if filepath.TailN("/a/b/c/d", 2) == "c/d" { pass = pass + 1 }

	// TailN — n=1.
	if filepath.TailN("/a/b/c", 1) == "c" { pass = pass + 1 }

	// TailN — n=0.
	if filepath.TailN("/a/b/c", 0) == "" { pass = pass + 1 }

	// TailN — relative.
	if filepath.TailN("a/b/c", 2) == "b/c" { pass = pass + 1 }

	// TailN — n > component count.
	if filepath.TailN("a/b", 10) == "a/b" { pass = pass + 1 }
	if filepath.TailN("/a/b", 10) == "a/b" { pass = pass + 1 }   // rooted-ness not preserved by Tail

	// TailN — empty path.
	if filepath.TailN("", 5) == "" { pass = pass + 1 }

	// TailN — single component.
	if filepath.TailN("foo", 1) == "foo" { pass = pass + 1 }

	// Deep nesting.
	if filepath.HeadN("/usr/local/share/man/man1", 3) == "/usr/local/share" { pass = pass + 1 }
	if filepath.TailN("/usr/local/share/man/man1", 2) == "man/man1" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 20 { ret 42 }
	ret 0
}
