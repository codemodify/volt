package main
import "log"
import "strings"

fun main() int {
	var pass int = 0

	// FirstNonEmpty — first slot wins.
	var a []string = new(3) []string { "first", "second", "third" }
	if strings.FirstNonEmpty(a) == "first" { pass = pass + 1 }

	// FirstNonEmpty — skip leading empties.
	var b []string = new(4) []string { "", "", "third", "fourth" }
	if strings.FirstNonEmpty(b) == "third" { pass = pass + 1 }

	// FirstNonEmpty — only last is non-empty.
	var c []string = new(3) []string { "", "", "last" }
	if strings.FirstNonEmpty(c) == "last" { pass = pass + 1 }

	// FirstNonEmpty — all empty → "".
	var d []string = new(3) []string { "", "", "" }
	if strings.FirstNonEmpty(d) == "" { pass = pass + 1 }

	// FirstNonEmpty — empty slice → "".
	var e []string = new(0) []string {}
	if strings.FirstNonEmpty(e) == "" { pass = pass + 1 }

	// FirstNonEmpty — single non-empty.
	var f []string = new(1) []string { "solo" }
	if strings.FirstNonEmpty(f) == "solo" { pass = pass + 1 }

	// FirstNonEmpty — single empty.
	var g []string = new(1) []string { "" }
	if strings.FirstNonEmpty(g) == "" { pass = pass + 1 }

	// FirstNonEmpty — typical config-fallback chain.
	var defaultHost string = "localhost"
	var envHost string = ""              // unset
	var cfgHost string = "production.example.com"
	var chain []string = new(3) []string { envHost, cfgHost, defaultHost }
	if strings.FirstNonEmpty(chain) == "production.example.com" { pass = pass + 1 }

	// FirstNonEmpty — all-empty chain falls to default.
	var chainEmpty []string = new(3) []string { "", "", defaultHost }
	if strings.FirstNonEmpty(chainEmpty) == "localhost" { pass = pass + 1 }

	// FirstNonEmpty — whitespace-only strings are non-empty (we only
	// check len > 0, not "blank").
	var ws []string = new(2) []string { "", " " }
	if strings.FirstNonEmpty(ws) == " " { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 10 { ret 42 }
	ret 0
}
