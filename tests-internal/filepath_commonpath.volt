package main
import "log"
import "path/filepath"

fun main() int {
	var pass int = 0

	// CommonPath — empty input.
	var empty []string = new(0) []string {}
	if filepath.CommonPath(empty) == "" { pass = pass + 1 }

	// CommonPath — single entry returns it verbatim.
	var single []string = new(1) []string { "foo/bar" }
	if filepath.CommonPath(single) == "foo/bar" { pass = pass + 1 }

	// CommonPath — two relative paths sharing prefix.
	var pair []string = new(2) []string { "a/b/c", "a/b/d" }
	if filepath.CommonPath(pair) == "a/b" { pass = pass + 1 }

	// CommonPath — three paths all sharing prefix.
	var triple []string = new(3) []string { "a/b/c", "a/b/d", "a/b/e" }
	if filepath.CommonPath(triple) == "a/b" { pass = pass + 1 }

	// CommonPath — no common prefix (relative).
	var disjoint []string = new(2) []string { "a/b", "x/y" }
	if filepath.CommonPath(disjoint) == "" { pass = pass + 1 }

	// CommonPath — rooted paths sharing prefix.
	var rooted []string = new(2) []string { "/usr/local/bin", "/usr/local/lib" }
	if filepath.CommonPath(rooted) == "/usr/local" { pass = pass + 1 }

	// CommonPath — rooted but no common components → "/".
	var rdisjoint []string = new(2) []string { "/a/b", "/x/y" }
	if filepath.CommonPath(rdisjoint) == "/" { pass = pass + 1 }

	// CommonPath — mismatched rootedness → "".
	var mixed []string = new(2) []string { "/a/b", "a/b" }
	if filepath.CommonPath(mixed) == "" { pass = pass + 1 }

	// CommonPath — one path is full prefix of the other.
	var prefix []string = new(2) []string { "a/b", "a/b/c" }
	if filepath.CommonPath(prefix) == "a/b" { pass = pass + 1 }

	// CommonPath — only first component matches.
	var part []string = new(2) []string { "a/b/c", "a/x/y" }
	if filepath.CommonPath(part) == "a" { pass = pass + 1 }

	// CommonPath — component-aware (NOT char-wise): "abc" / "abd" share nothing.
	var charLevel []string = new(2) []string { "abc/x", "abd/x" }
	if filepath.CommonPath(charLevel) == "" { pass = pass + 1 }

	// CommonPath — three rooted, full common root.
	var three []string = new(3) []string { "/var/log/a", "/var/log/b", "/var/log/c" }
	if filepath.CommonPath(three) == "/var/log" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 12 { ret 42 }
	ret 0
}
