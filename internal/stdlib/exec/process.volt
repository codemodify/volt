package exec

import "syscall"

// Process is a spawned child you can control: query its identity (PID/PPID),
// signal it (Stop/Kill), and Wait for it to finish. Returned by Cmd.Spawn
// and Cmd.SpawnWithStreams. The child does its own I/O directly on the fds
// it was given (no pipes, no pumping), so Wait just reaps.
type Process struct {
	pid  int
	ppid int
}

// PID is the child's process id.
fun (p *Process) PID() int {
	ret p.pid
}

// PPID is the child's parent — this process.
fun (p *Process) PPID() int {
	ret p.ppid
}

// Stop asks the child to terminate (SIGTERM). 0 on success, negative errno
// otherwise.
fun (p *Process) Stop() int {
	ret syscall.Kill(p.pid, 15)
}

// Kill forcibly terminates the child (SIGKILL) — use when Stop did not work.
fun (p *Process) Kill() int {
	ret syscall.Kill(p.pid, 9)
}

// Wait blocks until the child exits and returns its status (nil = clean exit
// 0; 128+signal if it was killed). It only reaps — the child read/wrote its
// own streams directly.
fun (p *Process) Wait() *ExitStatus {
	var code int = syscall.ProcWait(p.pid)
	if code == ExitSuccess {
		ret nil
	}
	var started bool = code != ExitNotStarted
	ret new ExitStatus {Code: code, Started: started}
}
