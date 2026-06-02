package main
import "log"
import "path/filepath"

// Positive test: filepath.Rel(basepath, target). Both inputs must
// share rootedness; output is the relative path from base to target.

fun main() int {
	var pass int = 0

	var r string = ""
	var e error = nil

	// Target is a subdirectory of base.
	r, e = filepath.Rel("/a/b", "/a/b/c")
	if e == nil { pass = pass + 1 }
	if r == "c" { pass = pass + 1 }

	// Target is the parent of base.
	r, e = filepath.Rel("/a/b/c", "/a/b")
	if e == nil { pass = pass + 1 }
	if r == ".." { pass = pass + 1 }

	// Sibling directories.
	r, e = filepath.Rel("/a/b", "/a/c")
	if e == nil { pass = pass + 1 }
	if r == "../c" { pass = pass + 1 }

	// Completely different roots under common root.
	r, e = filepath.Rel("/a/b/c", "/x/y")
	if e == nil { pass = pass + 1 }
	if r == "../../../x/y" { pass = pass + 1 }

	// Equal paths.
	r, e = filepath.Rel("/a/b", "/a/b")
	if r == "." { pass = pass + 1 }

	// Both unrooted.
	r, e = filepath.Rel("a/b", "a/b/c/d")
	if e == nil { pass = pass + 1 }
	if r == "c/d" { pass = pass + 1 }

	// Mixed rootedness → error.
	r, e = filepath.Rel("/a", "b")
	if e != nil { pass = pass + 1 }

	// Cleaning happens: trailing slashes don't matter.
	r, e = filepath.Rel("/a/b/", "/a/b/c/")
	if r == "c" { pass = pass + 1 }

	log.Println("pass=%d r=%s", pass, r)
	if pass == 13 { ret 42 }
	ret 0
}
