package main

import (
	"os"
	"fmt"
)

// A LOCAL type whose bare name collides with a stdlib type (os.File) must
// still dispatch correctly through a local interface. With package-qualified
// vtables, the value-receiver trampoline + vtable must agree on the owning
// package (the local one) — a Pass-786 fix: the trampoline define used the
// clobber-prone typeOwningPkg ("os") while the vtable entry used the local
// package, causing an undefined-symbol link failure. Returns 42 on pass.

type Tagger interface {
	Tag() string
}

// Local File — same bare name as os.File, VALUE receiver (uses the iface
// trampoline path, which is where the owner mismatch struck).
type File struct {
	n int
}

fun (f File) Tag() string {
	ret "local-file"
}

fun main() int {
	var (
		pass int = 0
		want int = 2
	)
	// Force os (and os.File, which satisfies io.Writer via value-receiver
	// trampolines) into the build so typeOwningPkg["File"] is contended.
	var (
		sout os.File = os.Stdout()
		n    int     = 0
		_e   error   = nil
	)
	n, _e = sout.Write("")
	if n == 0 {
		pass = pass + 1
	}

	// Box the LOCAL File into a local interface and dispatch.
	var t Tagger = new File {n: 7}
	if t.Tag() == "local-file" {
		pass = pass + 1
	}

	fmt.Printf("iface-local-collide pass=%d/%d\n", pass, want)
	if pass == want {
		ret 42
	}
	ret 1
}
