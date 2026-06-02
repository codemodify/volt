package main
import "log"
import "path/filepath"

fun main() int {
	var pass int = 0

	// JoinAll — empty / single.
	var empty []string = new(0) []string {}
	if filepath.JoinAll(empty) == "" { pass = pass + 1 }

	var oneEmpty []string = new(1) []string { "" }
	if filepath.JoinAll(oneEmpty) == "" { pass = pass + 1 }

	var oneA []string = new(1) []string { "a" }
	if filepath.JoinAll(oneA) == "a" { pass = pass + 1 }

	var oneRoot []string = new(1) []string { "/" }
	if filepath.JoinAll(oneRoot) == "/" { pass = pass + 1 }

	// JoinAll — typical multi-element relative.
	var rel3 []string = new(3) []string { "a", "b", "c" }
	if filepath.JoinAll(rel3) == "a/b/c" { pass = pass + 1 }

	// JoinAll — absolute paths.
	var abs []string = new(2) []string { "/", "a" }
	if filepath.JoinAll(abs) == "/a" { pass = pass + 1 }

	var absFull []string = new(4) []string { "/", "usr", "local", "bin" }
	if filepath.JoinAll(absFull) == "/usr/local/bin" { pass = pass + 1 }

	// JoinAll — empty elements skipped.
	var withEmpty []string = new(3) []string { "a", "", "b" }
	if filepath.JoinAll(withEmpty) == "a/b" { pass = pass + 1 }

	var allEmpty []string = new(3) []string { "", "", "" }
	if filepath.JoinAll(allEmpty) == "" { pass = pass + 1 }

	// JoinAll — trailing slash on a element collapses.
	var ts []string = new(2) []string { "a/", "b" }
	if filepath.JoinAll(ts) == "a/b" { pass = pass + 1 }

	// JoinAll — leading slash on a mid element collapses.
	var ls []string = new(2) []string { "a", "/b" }
	if filepath.JoinAll(ls) == "a/b" { pass = pass + 1 }

	// JoinAll — both ends adjacent slashes.
	var bothEnds []string = new(2) []string { "/a/", "b" }
	if filepath.JoinAll(bothEnds) == "/a/b" { pass = pass + 1 }

	// JoinAll — mid element that is only slashes is skipped.
	var midOnlySlashes []string = new(3) []string { "a", "//", "b" }
	if filepath.JoinAll(midOnlySlashes) == "a/b" { pass = pass + 1 }

	// JoinAll — leading empty then root then element → absolute.
	var leadEmpty []string = new(3) []string { "", "/", "a" }
	if filepath.JoinAll(leadEmpty) == "/a" { pass = pass + 1 }

	// JoinAll — root after content is a no-op separator.
	var rootAfter []string = new(2) []string { "a", "/" }
	if filepath.JoinAll(rootAfter) == "a" { pass = pass + 1 }

	// JoinAll — multi-leading-slash on second element collapses to one.
	var multiLead []string = new(2) []string { "a", "///b" }
	if filepath.JoinAll(multiLead) == "a/b" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
