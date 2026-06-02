package main
import "log"
import "strings"

// Positive test: strings.Cut / CutPrefix / CutSuffix — Go 1.18 / 1.20
// helpers. Cut returns (before, after, found); CutPrefix/CutSuffix
// return (rest, found).

fun main() int {
	var pass int = 0

	// Cut: sep present.
	var b1 string = ""
	var a1 string = ""
	var f1 bool = false
	b1, a1, f1 = strings.Cut("hello=world", "=")
	if f1 { pass = pass + 1 }
	if b1 == "hello" { pass = pass + 1 }
	if a1 == "world" { pass = pass + 1 }

	// Cut: sep not present.
	var b2 string = ""
	var a2 string = ""
	var f2 bool = false
	b2, a2, f2 = strings.Cut("noequals", "=")
	if !f2 { pass = pass + 1 }
	if b2 == "noequals" { pass = pass + 1 }
	if a2 == "" { pass = pass + 1 }

	// Cut: empty sep matches at 0.
	var b3 string = ""
	var a3 string = ""
	var f3 bool = false
	b3, a3, f3 = strings.Cut("abc", "")
	if f3 { pass = pass + 1 }
	if b3 == "" { pass = pass + 1 }
	if a3 == "abc" { pass = pass + 1 }

	// CutPrefix: present.
	var r1 string = ""
	var ok1 bool = false
	r1, ok1 = strings.CutPrefix("foobar", "foo")
	if ok1 { pass = pass + 1 }
	if r1 == "bar" { pass = pass + 1 }

	// CutPrefix: absent.
	var r2 string = ""
	var ok2 bool = false
	r2, ok2 = strings.CutPrefix("foobar", "baz")
	if !ok2 { pass = pass + 1 }
	if r2 == "foobar" { pass = pass + 1 }

	// CutSuffix: present.
	var r3 string = ""
	var ok3 bool = false
	r3, ok3 = strings.CutSuffix("foobar", "bar")
	if ok3 { pass = pass + 1 }
	if r3 == "foo" { pass = pass + 1 }

	// CutSuffix: absent.
	var r4 string = ""
	var ok4 bool = false
	r4, ok4 = strings.CutSuffix("foobar", "baz")
	if !ok4 { pass = pass + 1 }
	if r4 == "foobar" { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 17 { ret 42 }
	ret 0
}
