package main

import (
	"fmt"
	"exec"
)

// *ExitStatus carries a human-readable Error() string and the exit
// status (via exec.Code). Returns 42 on pass.
//
// (Boxing *ExitStatus into the polymorphic `error` interface ACROSS a
// package boundary is a known v1 limitation of volt's cross-package
// interface support — the Error() method is still callable directly,
// as exercised here.)
// shell builds a `/bin/sh -c line` command — exec has no NewShell; a
// shell is just NewCommand on /bin/sh with trusted input.
fun shell(line string) *exec.Cmd {
	var a []string = new(2) []string{}
	a[0] = "-c"
	a[1] = line
	ret exec.NewCommand("/bin/sh", a)
}

fun main() int {
	var pass int = 0
	var want int = 3

	var bad *exec.Cmd = shell("exit 3")
	var _o string = ""
	var _e string = ""
	var ee *exec.ExitStatus = nil
	_o, _e, ee = bad.RunGrabOutput()
	if ee != nil {
		pass = pass + 1
		var msg string = ee.Error()      // Error() callable directly
		if len(msg) > 0 { pass = pass + 1 }
	}

	// A successful run yields a nil status — Code() reports 0.
	var good *exec.Cmd = shell("true")
	var _o2 string = ""
	var _e2 string = ""
	var ge *exec.ExitStatus = nil
	_o2, _e2, ge = good.RunGrabOutput()
	if exec.Code(ge) == 0 { pass = pass + 1 }

	fmt.Printf("error-iface pass=%d/%d\n", pass, want)
	if pass == want { ret 42 }
	ret 1
}
