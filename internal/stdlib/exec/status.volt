package exec

type ExitStatus struct {
	Code    int   // exit status (128+signal if killed; ExitNotStarted if never started)
	Started bool  // false iff the process could not be spawned at all
}

const (
	ExitSuccess    = 0   // a clean run: the process exited with status 0
	ExitNotStarted = -1  // the process could not be spawned at all
)

fun (e *ExitStatus) Error() string {
	if !e.Started {
		ret "exec: command could not be started"
	}
	ret "exec: process exited with a non-zero status"
}
