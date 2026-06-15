package exec

import (
	"syscall"
	"strings"
	"strconv"
	"os"
)

type Cmd struct {
	Path string    // executable path; argv[0] handed to execve
	Args []string  // full argv (Args[0] is the program name)
	Dir  string    // working directory; "" = inherit the caller's
	Env  []string  // "KEY=VALUE" entries; empty = inherit the parent env
}

fun NewCommand(name string, args []string) *Cmd {
	// Resolve the program against $PATH using only cross-package reads
	// (a same-package helper call would consume `name`). `found` stays
	// "" when `name` already contains a '/' or no PATH entry matches.
	var found string = ""
	if strings.IndexByte(name, 47) < 0 {
		var penv string = os.Getenv("PATH")
		if len(penv) == 0 {
			penv = "/usr/bin:/bin"
		}
		var (
			dirs []string = strings.Split(penv, ":")
			nd   int      = len(dirs)
		)
		for i := 0; i < nd; i = i + 1 {
			if len(dirs[i]) == 0 {
				continue
			}
			var full string = dirs[i] + "/" + name
			if syscall.PathExists(full) {
				found = full
				break
			}
		}
	}
	// argv = [name, args...]; `name`'s last use is argv[0].
	var (
		n    int      = len(args)
		argv []string = new(n + 1) []string {}
	)
	argv[0] = name
	for i := 0; i < n; i = i + 1 {
		argv[i + 1] = args[i]
	}
	var path string = found
	if len(path) == 0 {
		path = argv[0]
	}
	var c *Cmd = new Cmd {Path: path, Args: argv, Dir: "", Env: new(0) []string {}}

	ret c
}

// Spawn launches the command inheriting the parent's standard streams (the
// child shares this process's stdin/stdout/stderr — the terminal) and
// returns a live Process to control. (nil, status) if it could not spawn.
fun (c *Cmd) Spawn() (*Process, *ExitStatus) {
	var pid int = syscall.ProcSpawnFds(c.Path, c.Args, c.Env, c.Dir, -1, -1, -1)
	if pid < 0 {
		ret nil, new ExitStatus {Code: ExitNotStarted, Started: false}
	}
	ret new Process {pid: pid, ppid: syscall.Getpid()}, nil
}

// SpawnWithStreams launches the command with its stdin/stdout/stderr wired
// DIRECTLY (dup3) to the given os.File descriptors — a file (os.Open/Create),
// the terminal (os.Stdout()/Stderr()), /dev/null, or a pipe end you hold (to
// talk to / read from the running child live). No pipes-we-pump, no copying:
// the child does its own I/O on the fds. Returns a live Process; (nil,
// status) if it could not spawn.
fun (c *Cmd) SpawnWithStreams(in os.File, out os.File, errw os.File) (*Process, *ExitStatus) {
	var pid int = syscall.ProcSpawnFds(c.Path, c.Args, c.Env, c.Dir, in.Fd(), out.Fd(), errw.Fd())
	if pid < 0 {
		ret nil, new ExitStatus {Code: ExitNotStarted, Started: false}
	}
	ret new Process {pid: pid, ppid: syscall.Getpid()}, nil
}

// tempBase is a per-thread unique path prefix under the temp dir. A thread
// is sequential, so its RunGrabOutput temp files never collide with its own
// or with another thread's (distinct kernel tids).
fun tempBase() string {
	ret os.TempDir() + "/volt-exec-" + strconv.Itoa(syscall.Gettid())
}

// RunWithInputGrabOutput runs the command to completion, feeding `input` to
// its stdin and capturing stdout + stderr into memory; returns (stdout,
// stderr, status), status nil on a clean exit 0. It wires the three streams
// to TEMP FILES — the child writes them DIRECTLY (no pump, no deadlock, any
// size) — then reaps and reads them back.
fun (c *Cmd) RunWithInputGrabOutput(input string) (string, string, *ExitStatus) {
	// `base + ".X"` is recomputed at each use because passing a string to a
	// call moves it; `base` itself is only read. The three os.File handles
	// auto-close (Drop) at function exit.
	var base string = tempBase()
	var _we error = os.WriteFile(base + ".in", input, 0600)
	inF, _ := os.Open(base + ".in")    // child stdin  ← input
	outF, _ := os.Create(base + ".out") // child stdout → file
	errF, _ := os.Create(base + ".err") // child stderr → file

	var p *Process = nil
	var ps *ExitStatus = nil
	p, ps = c.SpawnWithStreams(inF, outF, errF)
	if ps != nil {
		os.Remove(base + ".in")
		os.Remove(base + ".out")
		os.Remove(base + ".err")
		ret "", "", ps
	}
	var st *ExitStatus = p.Wait()

	out, _ := os.ReadFile(base + ".out")
	er, _ := os.ReadFile(base + ".err")
	os.Remove(base + ".in")
	os.Remove(base + ".out")
	os.Remove(base + ".err")
	ret out, er, st
}

// RunGrabOutput is RunWithInputGrabOutput with no stdin.
fun (c *Cmd) RunGrabOutput() (string, string, *ExitStatus) {
	ret c.RunWithInputGrabOutput("")
}
