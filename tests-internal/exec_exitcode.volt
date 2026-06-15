package main

import (
	"fmt"
	"exec"
)

// Exit-status reporting: a clean exit gives a nil status from
// RunGrabOutput (exec.Code 0); a non-zero exit gives a *ExitStatus
// carrying the code. Returns 42 on pass.
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
	var want int = 5

	// exit 7 → *ExitStatus with Code 7, Started true.
	var f *exec.Cmd = shell("exit 7")
	var _fo  string = ""
	var _ferr string = ""
	var fe *exec.ExitStatus = nil
	_fo, _ferr, fe = f.RunGrabOutput()
	if fe != nil { pass = pass + 1 }
	if exec.Code(fe) == 7 { pass = pass + 1 }
	if fe.Started { pass = pass + 1 }

	// exit 0 → nil status; exec.Code(nil) is 0.
	var t *exec.Cmd = shell("exit 0")
	var _to  string = ""
	var _terr string = ""
	var te *exec.ExitStatus = nil
	_to, _terr, te = t.RunGrabOutput()
	if te == nil { pass = pass + 1 }
	if exec.Code(te) == 0 { pass = pass + 1 }

	fmt.Printf("exitcode code7=%d pass=%d/%d\n", exec.Code(fe), pass, want)
	if pass == want { ret 42 }
	ret 1
}
