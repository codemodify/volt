package main

import (
	"io"
	"bytes"
	"strings"
	"os"
	"fmt"
)

// In-memory io.Reader: strings.NewReader / bytes.NewReader wrap a string /
// []byte as an io.Reader (concrete impl io.StringReader, a VALUE-receiver
// type so it boxes into the io.Reader interface across packages — volt's
// cross-package interface dispatch works for value receivers). io.Copy
// drains a reader into a writer. Returns 42 when every assertion holds.
fun main() int {
	var (
		pass int = 0
		want int = 6
	)
	// strings.NewReader -> io.Reader; Read is one-shot: first call returns
	// the whole content, the second returns "" (EOF). The EOF cursor is a
	// pointer-receiver mutation that persists THROUGH the io.Reader box —
	// the exact pattern that used to segfault before the interface-boxing
	// codegen fix.
	var (
		sr  io.Reader = strings.NewReader("hello world")
		s1  string    = ""
		_e1 error     = nil
	)
	s1, _e1 = sr.Read()
	if s1 == "hello world" {
		pass = pass + 1
	}
	var (
		s1b  string = "x"
		_e1b error  = nil
	)
	s1b, _e1b = sr.Read()
	if s1b == "" {
		pass = pass + 1
	}
	// bytes.NewReader -> io.Reader; content comes back as a string.
	var (
		raw []byte    = strings.ToBytes("abcde")
		br  io.Reader = bytes.NewReader(raw)
		s2  string    = ""
		_e2 error     = nil
	)
	s2, _e2 = br.Read()
	if s2 == "abcde" {
		pass = pass + 1
	}
	// io.Copy(dst Writer, src Reader): strings.NewReader -> os.Stdout (an
	// io.Writer). Returns the byte count written.
	var (
		n   int   = 0
		_e3 error = nil
	)
	n, _e3 = io.Copy(os.Stdout(), strings.NewReader("[io.Copy ok]\n"))
	if n == 13 {
		pass = pass + 1
	}
	// io.Copy from a bytes.NewReader too.
	var (
		n2  int   = 0
		_e4 error = nil
	)
	n2, _e4 = io.Copy(os.Stdout(), bytes.NewReader(strings.ToBytes("xy\n")))
	if n2 == 3 {
		pass = pass + 1
	}
	// An empty reader yields "".
	var (
		er  io.Reader = strings.NewReader("")
		s5  string    = "x"
		_e5 error     = nil
	)
	s5, _e5 = er.Read()
	if s5 == "" {
		pass = pass + 1
	}
	fmt.Printf("inmem-readers pass=%d/%d\n", pass, want)
	if pass == want {
		ret 42
	}
	ret 1
}
