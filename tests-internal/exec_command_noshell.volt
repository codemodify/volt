package main

import (
	"fmt"
	"strings"
	"exec"
)

// exec.NewCommand runs WITHOUT a shell: argv elements are passed literally,
// so shell metacharacters are NOT interpreted (no word-splitting, no
// $VAR expansion, no `;` command separation). This is the core safety
// property of running WITHOUT a shell (vs a manual /bin/sh -c). Returns 42 on pass.
fun main() int {
	var pass int = 0
	var want int = 3

	// echo with two args containing shell metacharacters.
	var args []string = new(2) []string{}
	args[0] = "a;b"
	args[1] = "$HOME"
	var c *exec.Cmd = exec.NewCommand("echo", args)
	var out string = ""
	var _er string = ""
	var ee *exec.ExitStatus = nil
	out, _er, ee = c.RunGrabOutput()
	var got string = strings.TrimSpace(out)

	// echo joins argv with a single space; metacharacters survive verbatim.
	if got == "a;b $HOME" { pass = pass + 1 }
	// Specifically, $HOME was NOT expanded and `;` did NOT split.
	if strings.Contains(got, "$HOME") { pass = pass + 1 }
	if ee == nil { pass = pass + 1 }

	fmt.Printf("noshell got=[%s] pass=%d/%d\n", got, pass, want)
	if pass == want { ret 42 }
	ret 1
}
