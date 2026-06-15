// exec_styles.volt — ways to run a command.
//
// RunGrabOutput / RunWithInputGrabOutput capture stdout+stderr as strings
// (via temp files, no pump). SpawnWithStreams wires the child's fds directly
// to os.File handles (a file, the terminal, a pipe). Spawn returns a live
// Process (PID, Stop/Kill, Wait) on the inherited terminal.

package main

import (
	"exec"
	"io"
	"os"
	"strings"
	"fmt"
)

fun newShellCmd(line string) *exec.Cmd {
	ret exec.NewCommand("/bin/sh", new(2) []string{"-c", line})
}

fun main() {
	// capture stdout
	capCmd := newShellCmd("echo hello")
	out, _, _ := capCmd.RunGrabOutput()
	fmt.Printf("1 capture      : %s", out)

	// feed stdin + capture
	upCmd := newShellCmd("tr a-z A-Z")
	shout, _, _ := upCmd.RunWithInputGrabOutput("shout\n")
	fmt.Printf("2 stdin=string : %s", shout)

	// redirect stdout straight to a file (os.File, no pump)
	logf, _ := os.Create("/tmp/volt-exec-sample.log")
	dn, _ := os.Open("/dev/null")
	fileCmd := newShellCmd("echo to-a-file")
	fp, _ := fileCmd.SpawnWithStreams(dn, logf, logf)
	fp.Wait()
	saved, _ := os.ReadFile("/tmp/volt-exec-sample.log")
	fmt.Printf("3 ->file       : %s", saved)
	os.Remove("/tmp/volt-exec-sample.log")

	// run on the terminal — Spawn inherits stdin/stdout/stderr
	fmt.Printf("4 ->terminal   : ")
	liveCmd := newShellCmd("echo live")
	lp, _ := liveCmd.Spawn()
	lp.Wait()

	// a live Process: PID now, exit status after Wait
	job := newShellCmd("exit 7")
	jp, _ := job.Spawn()
	jw := jp.Wait()
	fmt.Printf("5 spawn pid=%d : exit %d\n", jp.PID(), exec.Code(jw))

	// exit status — exec.Code is nil-safe (0 clean, -1 never started)
	failedCmd := newShellCmd("exit 3")
	_, _, st := failedCmd.RunGrabOutput()
	fmt.Printf("6 exit code    : %d\n", exec.Code(st))

	// io.Copy drains any reader into any writer
	dst := io.NewStringWriter()
	io.Copy(dst, strings.NewReader("copied-bytes"))
	fmt.Printf("7 io.Copy      : %s\n", dst.String())
}
