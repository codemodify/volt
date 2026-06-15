// volt:noformat — spec file; hand-aligned.
// =====================================================================
// exec.volt — the `exec` package: running external programs
// =====================================================================
// A volt port of Go's os/exec. It replaces the old shell-only trio
// (os.Run / os.Ok / os.Output, removed) with a configurable command
// value run, by default, WITHOUT a shell.
//
// The headline difference: `exec.NewCommand(name, args)` execve's the
// program directly with a literal argv vector — the shell never sees
// the arguments, so there is no word-splitting, globbing, or injection.
// Untrusted data can be passed as an argument safely. There is no shell
// convenience constructor — when you actually want a pipeline / redirect /
// glob, run a shell yourself: `exec.NewCommand("/bin/sh", ["-c", line])`,
// with trusted `line` only.
//
// Two layers:
//
//   * Spawn / SpawnWithStreams — launch the child and hand back a live
//     `*Process` (PID/PPID, Stop, Kill, Wait). SpawnWithStreams wires the
//     child's stdin/stdout/stderr DIRECTLY to os.File descriptors you give
//     it (dup3); the child does its own I/O — NO pumping, NO copying.
//   * RunGrabOutput / RunWithInputGrabOutput — blocking convenience that
//     captures stdout+stderr into strings via temp files (the child writes
//     them directly, then we read them back — still no pump).
//
// Runtime intrinsics (package syscall → no-libc runtime symbols):
//
//   syscall.ProcSpawnFds(path,argv,env,dir, inFd,outFd,errFd)  volt_proc_spawn_fds
//   syscall.ProcWait(pid)                                      volt_exec_wait
//   syscall.Kill(pid,sig) / Getpid() / Gettid()                volt_kill/getpid/gettid
//
// volt_proc_spawn_fds issues raw syscalls only — clone(SIGCHLD) / chdir /
// (per supplied fd) dup3 / execve — and returns the child pid. A fd of -1
// leaves that stream inherited from the parent. There are no pipes the
// runtime drains and no worker threads anywhere. Wait() just wait4's.
//
// SIGPIPE is ignored process-wide at startup (so a write to a child that
// exited early — e.g. `head` — returns -EPIPE instead of killing us) and
// reset to default in each forked child (so pipelines like `yes | head`
// still die normally).

// ---- public surface (package exec) ----------------------------------
//
//   type Cmd struct { Path; Args []string; Dir; Env []string }
//   type ExitStatus struct { Code int; Started bool }
//   const ExitSuccess = 0 / ExitNotStarted = -1   Code sentinels
//
//   NewCommand(name, args []string) *Cmd   no shell; PATH-resolves `name`
//                                          (for a shell: NewCommand("/bin/sh", ["-c", line]))
//   LookPath(name string)        (string, error)   $PATH search (F_OK)
//
//   // launch → live Process
//   (c *Cmd) Spawn()                                  (*Process, *ExitStatus)
//                             inherit the terminal's stdin/stdout/stderr
//   (c *Cmd) SpawnWithStreams(in os.File, out os.File, errw os.File)
//                                                     (*Process, *ExitStatus)
//                             dup3 the child's 0/1/2 to these fds directly
//   (p *Process) PID()  int / PPID() int             identity
//   (p *Process) Stop() int                          SIGTERM   (0 = ok)
//   (p *Process) Kill() int                          SIGKILL
//   (p *Process) Wait() *ExitStatus                  reap (no pump)
//
//   // blocking capture-to-strings (temp files)
//   (c *Cmd) RunGrabOutput()                  (string, string, *ExitStatus)
//   (c *Cmd) RunWithInputGrabOutput(input string)
//                                             (string, string, *ExitStatus)
//
//   (e *ExitStatus) Error()    string               human-readable
//   Code(e *ExitStatus)        int                  e.Code, or 0 if nil

// ---- example --------------------------------------------------------
//
//   // No shell — `arg` cannot break out, even if attacker-controlled.
//   g := exec.NewCommand("git", []string{"show", arg})
//   out, errOut, st := g.RunGrabOutput()
//   if st != nil { log.Println("git failed:", exec.Code(st), errOut) }
//
//   // Feed stdin + capture:
//   up := exec.NewCommand("tr", []string{"a-z", "A-Z"})
//   shout, _, _ := up.RunWithInputGrabOutput("hello\n")    // "HELLO\n"
//
//   // Redirect stdout straight to a file (no pump, any size):
//   logf, _ := os.Create("build.log")
//   dn, _   := os.Open("/dev/null")
//   p, _ := exec.NewCommand("make", nil).SpawnWithStreams(dn, logf, logf)
//   p.Wait()
//
//   // A live process you control:
//   srv := exec.NewCommand("server", []string{"--port", "8080"})
//   sp, _ := srv.Spawn()                 // inherits the terminal
//   log.Println("pid", sp.PID())
//   sp.Stop()                            // SIGTERM; sp.Kill() if ignored
//   ws := sp.Wait()
//
//   // Interactive: hand the child a pipe end and talk to it live.
//   r, w := os.Pipe()                    // you keep w; child reads r
//   ip, _ := cmd.SpawnWithStreams(r, os.Stdout(), os.Stderr())
//   w.Write("command\n")                 // drive it on your own schedule
//   ip.Wait()

// ---- exit status (not "error") --------------------------------------
// A non-zero exit is a STATUS, not inherently an error — grep exits 1 on
// no-match, diff exits 1 on differences — so the type is ExitStatus and the
// caller decides whether a code is a problem. The exec calls return a
// CONCRETE *ExitStatus (nil on a clean exit 0) rather than the `error`
// interface, because volt has no type-assertion to recover a code from a
// boxed error yet. Read it directly: `if s != nil { s.Code }`, or
// `exec.Code(s)` (0 when nil, -1 when the process could not be started; a
// signal-killed child reports 128+signal, e.g. 143 SIGTERM / 137 SIGKILL).
// *ExitStatus DOES carry an Error() method, so it can be used as an `error`
// when you want that; boxing it into the polymorphic `error` interface
// across the package boundary is a known v1 limitation.

// ---- streams (os.File, no pumping) ----------------------------------
// SpawnWithStreams takes three os.File values and dup3's their fds onto the
// child's 0/1/2 — the kernel moves the bytes, we never copy. Hand it:
//   * a file        — os.Open / os.Create
//   * the terminal  — os.Stdin() / os.Stdout() / os.Stderr()
//   * a black hole  — os.Open("/dev/null")
//   * a pipe end    — os.Pipe() (you hold the other end → live interaction)
// There is no "nil" stream (os.File is a value); pass /dev/null to discard
// or os.Std*() to inherit. Spawn() = SpawnWithStreams with all three
// inherited.
//
// RunGrabOutput / RunWithInputGrabOutput capture to strings WITHOUT a pump
// by routing the child's stdio through TEMP FILES (under os.TempDir(), named
// by kernel thread id so concurrent calls don't collide): write stdin to a
// file, point stdout/stderr at files, spawn, Wait, read the files back,
// delete them. The child writes a regular file directly — no pipe to drain,
// no deadlock, any output size.

// ---- not in v1 ------------------------------------------------------
//   - in-memory io.Reader/io.Writer streams on Spawn (use os.File; for an
//     in-memory capture use RunGrabOutput, which already does temp files)
//   - non-blocking TryWait (wait4 WNOHANG)
//   - X_OK executable-bit check in LookPath (uses F_OK existence)
//   - per-command timeout / cancellation
