package main

import (
	"fmt"
	"strings"
	"exec"
)

// Exercises the exec package end-to-end:
//   c.RunGrabOutput(input)  — feed stdin, run, wait, capture out+err+status
//   *ExitStatus / exec.Code — exit-status reporting
// Returns 42 when every assertion holds (correctness-harness sentinel).
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

	// 1. Shell capture. (Multi-return method calls need a bound receiver,
	// so bind the *Cmd before calling .RunGrabOutput(input).)
	var sh *exec.Cmd = shell("echo volt-exec-works")
	var who string = ""
	var _werr string = ""
	var e1 *exec.ExitStatus = nil
	who, _werr, e1 = sh.RunGrabOutput()
	if strings.Contains(who, "volt-exec-works") { pass = pass + 1 }
	if e1 == nil { pass = pass + 1 }

	// 2. A program that succeeds → nil status.
	var okc *exec.Cmd = exec.NewCommand("true", new(0) []string{})
	var _oo string = ""
	var _oe string = ""
	var oke *exec.ExitStatus = nil
	_oo, _oe, oke = okc.RunGrabOutput()
	if oke == nil { pass = pass + 1 }

	// 3. A program that fails → *ExitStatus with Code 1.
	var badc *exec.Cmd = exec.NewCommand("false", new(0) []string{})
	var _bo string = ""
	var _be string = ""
	var fe *exec.ExitStatus = nil
	_bo, _be, fe = badc.RunGrabOutput()
	if exec.Code(fe) == 1 { pass = pass + 1 }

	// 4. Captured pipeline output — proves the /bin/sh -c command pipes.
	var pipe *exec.Cmd = shell("printf 'a\\nb\\nc\\n' | wc -l")
	var n string = ""
	var _nerr string = ""
	var _e2 *exec.ExitStatus = nil
	n, _nerr, _e2 = pipe.RunGrabOutput()
	if strings.TrimSpace(n) == "3" { pass = pass + 1 }

	fmt.Printf("proc_exec pass=%d/%d\n", pass, want)
	if pass == want { ret 42 }
	ret 1
}
