package main
import "log"
import "os"

// Positive test: os.Stdout / os.Stderr — File handles wrapping fd 1
// and 2. Drop and Close are no-ops (pinned). Write delivers bytes
// to the underlying fd.

fun main() int {
	var pass int = 0

	// Write to stdout: bytes count returned, no error.
	var out os.File = os.Stdout()
	var n1 int = 0
	var e1 error = nil
	n1, e1 = out.Write("STDOUT_TEST\n")
	if e1 == nil { pass = pass + 1 }
	if n1 == 12 { pass = pass + 1 }

	// Close should be a no-op (pinned).
	var ce1 error = out.Close()
	if ce1 == nil { pass = pass + 1 }

	// Write to stderr.
	var err os.File = os.Stderr()
	var n2 int = 0
	var e2 error = nil
	n2, e2 = err.Write("STDERR_TEST\n")
	if e2 == nil { pass = pass + 1 }
	if n2 == 12 { pass = pass + 1 }

	// Stdin handle constructible (we don't read since the test
	// runs with closed stdin in the regression harness).
	var sin os.File = os.Stdin()
	var sce error = sin.Close()
	if sce == nil { pass = pass + 1 }

	// log.Println uses fd 2 (stderr) — it must still work after
	// our writes (i.e. stderr hasn't been closed).
	log.Println("pass=%d", pass)

	// Writing to stdout AFTER calling Close should still work
	// since Close on a pinned File is a no-op at the syscall level
	// (it does flip the local `closed` flag — but each os.Stdout()
	// call returns a fresh value with closed=false).
	var out2 os.File = os.Stdout()
	var n3 int = 0
	var e3 error = nil
	n3, e3 = out2.Write("STDOUT_AGAIN\n")
	if e3 == nil { pass = pass + 1 }
	if n3 > 0 { pass = pass + 1 }

	if pass == 8 { ret 42 }
	ret 0
}
