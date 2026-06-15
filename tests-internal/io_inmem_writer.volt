package main

import (
	"io"
	"exec"
	"strings"
	"fmt"
)

// io.StringWriter is the stdlib's in-memory io.Writer sink: a *StringWriter
// boxed into io.Writer SHARES its state (pointer-receiver Write), so writes
// through the box persist and String() reads them back. This is the payoff
// of the Pass-785/786 interface-boxing fixes (boxing a concrete *T — incl.
// a *T VARIABLE — now wraps the real pointer, not a value copy). Returns 42
// when every assertion holds.
fun shell(line string) *exec.Cmd {
	var a []string = new(2) []string {}
	a[0] = "-c"
	a[1] = line
	ret exec.NewCommand("/bin/sh", a)
}

fun main() int {
	var (
		pass int = 0
		want int = 4
	)
	// 1. io.Copy drains a reader into an in-memory sink.
	var (
		w1 *io.StringWriter = io.NewStringWriter()
		_n int              = 0
		_e error            = nil
	)
	_n, _e = io.Copy(w1, strings.NewReader("hello world"))
	if w1.String() == "hello world" {
		pass = pass + 1
	}
	// 2. Writing through the boxed io.Writer accumulates (two Writes).
	var (
		w2   *io.StringWriter = io.NewStringWriter()
		sink io.Writer        = w2
		_n2  int              = 0
		_e2  error            = nil
	)
	_n2, _e2 = sink.Write("ab")
	var (
		_n3 int   = 0
		_e3 error = nil
	)
	_n3, _e3 = sink.Write("cd")
	if w2.String() == "abcd" {
		pass = pass + 1
	}
	// 3. exec.Cmd.RunGrabOutput captures a child's stdout into a string (via
	//    temp files); collect it into a StringWriter to exercise the sink too.
	var (
		c    *exec.Cmd        = shell("echo CAPTURED")
		out  *io.StringWriter = io.NewStringWriter()
		grab string           = ""
		_ge  string           = ""
		gs   *exec.ExitStatus = nil
	)
	grab, _ge, gs = c.RunGrabOutput()
	if gs == nil {
		pass = pass + 1
	}
	var (
		_gn int   = 0
		_gw error = nil
	)
	_gn, _gw = out.Write(strings.TrimSpace(grab))
	if out.String() == "CAPTURED" {
		pass = pass + 1
	}
	fmt.Printf("inmem-writer pass=%d/%d out=[%s]\n", pass, want, out.String())
	if pass == want {
		ret 42
	}
	ret 1
}
