package main
import "log"
import "path/filepath"

// Positive test: filepath.IsAbs / Split / Clean.

fun main() int {
	var pass int = 0

	// IsAbs.
	if filepath.IsAbs("/tmp/foo") { pass = pass + 1 }
	if filepath.IsAbs("/") { pass = pass + 1 }
	if !filepath.IsAbs("foo/bar") { pass = pass + 1 }
	if !filepath.IsAbs("./foo") { pass = pass + 1 }
	if !filepath.IsAbs("") { pass = pass + 1 }

	// Split.
	var d string = ""
	var f string = ""
	d, f = filepath.Split("a/b/c.txt")
	if d == "a/b/" { pass = pass + 1 }
	if f == "c.txt" { pass = pass + 1 }

	d, f = filepath.Split("foo.txt")
	if d == "" { pass = pass + 1 }
	if f == "foo.txt" { pass = pass + 1 }

	d, f = filepath.Split("/tmp/")
	if d == "/tmp/" { pass = pass + 1 }
	if f == "" { pass = pass + 1 }

	// Clean.
	if filepath.Clean("a/b/c") == "a/b/c" { pass = pass + 1 }
	if filepath.Clean("a//b") == "a/b" { pass = pass + 1 }
	if filepath.Clean("a/./b") == "a/b" { pass = pass + 1 }
	if filepath.Clean("a/b/../c") == "a/c" { pass = pass + 1 }
	if filepath.Clean("/a/b/../") == "/a" { pass = pass + 1 }
	if filepath.Clean("/../a") == "/a" { pass = pass + 1 }
	if filepath.Clean("") == "." { pass = pass + 1 }
	if filepath.Clean(".") == "." { pass = pass + 1 }
	if filepath.Clean("/") == "/" { pass = pass + 1 }
	if filepath.Clean("a/b/c/") == "a/b/c" { pass = pass + 1 }
	if filepath.Clean("./foo") == "foo" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 22 { ret 42 }
	ret 0
}
