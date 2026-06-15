package main

import (
	"exec"
	"os"
	"strings"
	"fmt"
)

// exec.Cmd.SpawnWithStreams(in, out, err os.File) wires the child's
// stdin/stdout/stderr DIRECTLY (dup3) to real fds — no pump. Here we drive
// it with files: stdin from a file (grep -q makes the EXIT CODE depend on
// its content) and stdout to a file we read back. Returns 42 on pass.
fun shell(line string) *exec.Cmd {
	var a []string = new(2) []string {}
	a[0] = "-c"
	a[1] = line
	ret exec.NewCommand("/bin/sh", a)
}

// runFile opens inPath as the child's stdin and outPath as its stdout
// (stderr → /dev/null), spawns, and waits — returning the status.
fun runFile(c *exec.Cmd, inPath string, outPath string) *exec.ExitStatus {
	inF, _ := os.Open(inPath)
	outF, _ := os.Create(outPath)
	dn, _ := os.Open("/dev/null")
	var p *exec.Process = nil
	var ps *exec.ExitStatus = nil
	p, ps = c.SpawnWithStreams(inF, outF, dn)
	if ps != nil {
		ret ps
	}
	ret p.Wait()
}

fun main() int {
	var (
		pass int = 0
		want int = 3
	)
	// 1. stdin file contains "hello" -> grep -q exits 0.
	var _w1 error = os.WriteFile("/tmp/volt_ess_in", "say hello there", 0600)
	var s1 *exec.ExitStatus = runFile(shell("grep -q hello"), "/tmp/volt_ess_in", "/tmp/volt_ess_out")
	if s1 == nil {
		pass = pass + 1
	}
	// 2. stdin without "hello" -> grep -q exits 1.
	var _w2 error = os.WriteFile("/tmp/volt_ess_in", "goodbye", 0600)
	var s2 *exec.ExitStatus = runFile(shell("grep -q hello"), "/tmp/volt_ess_in", "/tmp/volt_ess_out")
	if exec.Code(s2) == 1 {
		pass = pass + 1
	}
	// 3. stdout redirected to a file — verify the bytes landed (no pump).
	var _w3 error = os.WriteFile("/tmp/volt_ess_in", "", 0600)
	var s3 *exec.ExitStatus = runFile(shell("echo REDIRECTED"), "/tmp/volt_ess_in", "/tmp/volt_ess_out")
	var captured string = ""
	var _re error = nil
	captured, _re = os.ReadFile("/tmp/volt_ess_out")
	if s3 == nil && strings.TrimSpace(captured) == "REDIRECTED" {
		pass = pass + 1
	}
	os.Remove("/tmp/volt_ess_in")
	os.Remove("/tmp/volt_ess_out")
	fmt.Printf("spawn-streams pass=%d/%d\n", pass, want)
	if pass == want {
		ret 42
	}
	ret 1
}
