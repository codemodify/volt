package main

import (
	"fmt"
	"strings"
	"exec"
)

// exec.LookPath resolves a bare program name against $PATH (and returns
// a name containing '/' unchanged). A bogus name yields an error.
// Returns 42 on pass.
fun main() int {
	var pass int = 0
	var want int = 4

	// `sh` resolves to an absolute path with no error.
	var p string = ""
	var e error = nil
	p, e = exec.LookPath("sh")
	if e == nil { pass = pass + 1 }
	if strings.Contains(p, "/") { pass = pass + 1 }

	// A name that contains '/' is returned unchanged.
	var q string = ""
	var e2 error = nil
	q, e2 = exec.LookPath("/bin/sh")
	if e2 == nil { if q == "/bin/sh" { pass = pass + 1 } }

	// A bogus name is not found.
	var _r string = ""
	var e3 error = nil
	_r, e3 = exec.LookPath("definitely-not-a-real-binary-xyzzy")
	if e3 != nil { pass = pass + 1 }

	fmt.Printf("lookpath sh=[%s] pass=%d/%d\n", p, pass, want)
	if pass == want { ret 42 }
	ret 1
}
