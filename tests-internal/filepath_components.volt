package main
import "log"
import "path/filepath"

// Positive test: filepath.Components.

fun main() int {
	var pass int = 0

	// Absolute multi-segment.
	var a []string = filepath.Components("/a/b/c")
	if len(a) == 3 { pass = pass + 1 }
	if a[0] == "a" { pass = pass + 1 }
	if a[1] == "b" { pass = pass + 1 }
	if a[2] == "c" { pass = pass + 1 }

	// Relative.
	var b []string = filepath.Components("a/b/c")
	if len(b) == 3 { pass = pass + 1 }
	if b[0] == "a" { pass = pass + 1 }

	// Single segment.
	var s []string = filepath.Components("foo")
	if len(s) == 1 { pass = pass + 1 }
	if s[0] == "foo" { pass = pass + 1 }

	// Trailing slash collapsed.
	var ts []string = filepath.Components("/foo/bar/")
	if len(ts) == 2 { pass = pass + 1 }
	if ts[0] == "foo" { pass = pass + 1 }
	if ts[1] == "bar" { pass = pass + 1 }

	// Multiple slashes collapsed.
	var ms []string = filepath.Components("/a//b///c")
	if len(ms) == 3 { pass = pass + 1 }
	if ms[0] == "a" { pass = pass + 1 }
	if ms[2] == "c" { pass = pass + 1 }

	// Root.
	if len(filepath.Components("/")) == 0 { pass = pass + 1 }

	// Empty.
	if len(filepath.Components("")) == 0 { pass = pass + 1 }

	// Just slashes.
	if len(filepath.Components("///")) == 0 { pass = pass + 1 }

	// Dot segments preserved (we don't normalize).
	var d []string = filepath.Components("./a/../b")
	if len(d) == 4 { pass = pass + 1 }
	if d[0] == "." { pass = pass + 1 }
	if d[1] == "a" { pass = pass + 1 }
	if d[2] == ".." { pass = pass + 1 }
	if d[3] == "b" { pass = pass + 1 }

	// Re-join via filepath.Join roundtrip.
	var rj []string = filepath.Components("/x/y/z")
	if rj[0] == "x" { pass = pass + 1 }
	if rj[2] == "z" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 24 { ret 42 }
	ret 0
}
