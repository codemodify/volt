// Package stdlib embeds the volt standard-library source files so the
// compiler binary is self-contained. The driver compiles these alongside
// user code when their packages are imported.
//
// Note: the syscall package is a placeholder for `import "syscall"`. Its
// `Write`/`Exit` functions are compiler intrinsics — the codegen lowers
// them directly to calls into the runtime. So syscall.volt contains no
// function bodies.
package stdlib

import (
	"embed"
	"io/fs"
)

//go:embed log/log.volt os/os.volt syscall/syscall.volt time/time.volt
var files embed.FS

// Source returns the source bytes for the named package's main file,
// or (nil, false) if the package is unknown to the embedded stdlib.
func Source(pkg string) ([]byte, bool) {
	b, err := fs.ReadFile(files, pkg+"/"+pkg+".volt")
	if err != nil {
		return nil, false
	}
	return b, true
}
