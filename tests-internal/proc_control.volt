// exec.Cmd.Spawn returns a live Process you can query and signal: PID/PPID,
// Stop (SIGTERM), Kill (SIGKILL), Wait. A signal-killed child reports exit
// code 128+signal (143 for SIGTERM, 137 for SIGKILL). Returns 42 on pass.
package main

import "exec"
import "fmt"

fun main() int {
	var pass int = 0
	var want int = 4

	// Stop a long sleep with SIGTERM.
	var a *exec.Cmd = exec.NewCommand("sleep", new(1) []string{"30"})
	var pa *exec.Process = nil
	var sa *exec.ExitStatus = nil
	pa, sa = a.Spawn()
	if sa == nil {
		if pa.PID() > 0 && pa.PPID() > 0 {
			pass = pass + 1
		}
		var rc int = pa.Stop()
		if rc == 0 {
			pass = pass + 1
		}
		var wa *exec.ExitStatus = pa.Wait()
		if exec.Code(wa) == 143 { // 128 + SIGTERM(15)
			pass = pass + 1
		}
	}

	// Kill another with SIGKILL.
	var b *exec.Cmd = exec.NewCommand("sleep", new(1) []string{"30"})
	var pb *exec.Process = nil
	var sb *exec.ExitStatus = nil
	pb, sb = b.Spawn()
	if sb == nil {
		pb.Kill()
		var wb *exec.ExitStatus = pb.Wait()
		if exec.Code(wb) == 137 { // 128 + SIGKILL(9)
			pass = pass + 1
		}
	}

	fmt.Printf("proc-control pass=%d/%d\n", pass, want)
	if pass == want {
		ret 42
	}
	ret 1
}
