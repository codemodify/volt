// exec.RunGrabOutput pumps stdin, stdout, and stderr concurrently — stdin
// fed on this thread, stdout + stderr each drained on their own `run`
// thread — so a child that simultaneously consumes a large stdin while
// echoing it back (or flooding stderr) can't wedge on a full pipe buffer.
// That full-duplex deadlock is exactly what the old feed-then-drain engine
// risked once Input exceeded the ~64 KB pipe capacity. This pushes 256 KB
// through every stream and checks the byte counts. Returns 42 on pass.
package main

import "exec"
import "strings"
import "fmt"

fun shell(line string) *exec.Cmd {
	ret exec.NewCommand("/bin/sh", new(2) []string{"-c", line})
}

fun main() int {
	var pass int = 0
	var want int = 3
	var big string = strings.Repeat("x", 262144) // 256 KB >> 64 KB pipe buffer

	// 1. Full-duplex: cat reads 256 KB stdin AND writes it back to stdout at
	//    the same time — the classic deadlock if stdin is fed before stdout
	//    is drained.
	dup := shell("cat")
	out, _, _ := dup.RunWithInputGrabOutput(big)
	if len(out) == 262144 {
		pass = pass + 1
	}

	// 2. Large stdin consumed while the child also floods stderr with 256 KB.
	noisy := shell("cat >/dev/null; yes e | head -c 262144 1>&2")
	_, errs, _ := noisy.RunWithInputGrabOutput(big)
	if len(errs) == 262144 {
		pass = pass + 1
	}

	// 3. Exit status threads back through the pump unchanged.
	quiet := shell("cat >/dev/null")
	_, _, st := quiet.RunWithInputGrabOutput(big)
	if exec.Code(st) == 0 {
		pass = pass + 1
	}

	fmt.Printf("exec-pump-deadlock pass=%d/%d\n", pass, want)
	if pass == want {
		ret 42
	}
	ret 1
}
