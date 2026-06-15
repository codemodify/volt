package exec

import (
	"strings"
	"os"
	"syscall"
	"errors"
)

fun Code(e *ExitStatus) int {
	if e == nil {
		ret ExitSuccess
	}
	ret e.Code
}

fun LookPath(name string) (string, error) {
	if strings.IndexByte(name, 47) >= 0 {
		// contains '/'
		ret name, nil
	}
	var path string = os.Getenv("PATH")
	if len(path) == 0 {
		path = "/usr/bin:/bin"
	}
	var (
		dirs []string = strings.Split(path, ":")
		nd   int      = len(dirs)
	)
	for i := 0; i < nd; i = i + 1 {
		if len(dirs[i]) == 0 {
			continue
		}
		var full string = dirs[i] + "/" + name
		if syscall.PathExists(full) {
			ret full, nil
		}
	}
	ret "", errors.New("exec: executable file not found in $PATH")
}
