package main

import (
	"fmt"
	"strings"
	"exec"
)

// RunGrabOutput captures stdout and stderr SEPARATELY (both returned);
// the Input field feeds the child's stdin. Together these exercise the
// runtime's two-pipe drain and stdin-feed paths. Returns 42 on pass.
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
	var want int = 4

	// RunGrabOutput returns stdout and stderr as two separate strings.
	var c *exec.Cmd = shell("echo to-out; echo to-err 1>&2")
	var out string = ""
	var er  string = ""
	var e1 *exec.ExitStatus = nil
	out, er, e1 = c.RunGrabOutput()
	if strings.Contains(out, "to-out") { pass = pass + 1 }
	if strings.Contains(er, "to-err") { pass = pass + 1 }
	if e1 == nil { pass = pass + 1 }

	// Input is fed to the child's stdin; `cat` echoes it back. Use a
	// largish payload to stress the stdin pipe / drain interplay.
	var cat *exec.Cmd = exec.NewCommand("cat", new(0) []string{})
	var echoed string = ""
	var _er2 string = ""
	var _e2 *exec.ExitStatus = nil
	echoed, _er2, _e2 = cat.RunWithInputGrabOutput(strings.Repeat("xy", 5000))   // 10000 bytes in
	if len(echoed) == 10000 { pass = pass + 1 }

	fmt.Printf("combined+input pass=%d/%d (echoed=%d bytes)\n", pass, want, len(echoed))
	if pass == want { ret 42 }
	ret 1
}
