package main
import "log"
import "path/filepath"

fun main() int {
	var pass int = 0

	// Simple cases.
	if filepath.Stem("readme") == "readme" { pass = pass + 1 }
	if filepath.Stem("foo.txt") == "foo" { pass = pass + 1 }
	if filepath.Stem("foo.tar.gz") == "foo.tar" { pass = pass + 1 }   // only last ext stripped

	// With directory prefix.
	if filepath.Stem("/usr/local/lib/libfoo.so") == "libfoo" { pass = pass + 1 }
	if filepath.Stem("./bin/myapp.exe") == "myapp" { pass = pass + 1 }
	if filepath.Stem("a/b/c.d") == "c" { pass = pass + 1 }

	// No extension.
	if filepath.Stem("/usr/local/bin/tool") == "tool" { pass = pass + 1 }
	if filepath.Stem("Makefile") == "Makefile" { pass = pass + 1 }

	// Root / edge.
	if filepath.Stem("/") == "/" { pass = pass + 1 }
	if filepath.Stem("") == "." { pass = pass + 1 }    // Base("") returns "."

	// Hidden file basename — SplitExt treats leading-dot as no-ext,
	// so the whole basename survives.
	if filepath.Stem(".bashrc") == ".bashrc" { pass = pass + 1 }

	// Hidden file in directory.
	if filepath.Stem("/home/user/.profile") == ".profile" { pass = pass + 1 }

	// Combination with HasExt.
	var p string = "/build/output.bin"
	if filepath.Stem(p) == "output" { pass = pass + 1 }
	if filepath.HasExt(p, "bin") { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 14 { ret 42 }
	ret 0
}
