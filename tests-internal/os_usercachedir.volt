package main
import "log"
import "os"
import "strings"

fun main() int {
	var pass int = 0

	var dir string = ""
	var err error = nil

	// UserCacheDir succeeds in normal test environments where HOME
	// is set (regression scripts run under a real Linux user).
	dir, err = os.UserCacheDir()
	if err == nil { pass = pass + 1 }

	// Non-empty result.
	if len(dir) > 0 { pass = pass + 1 }

	// Result is either $XDG_CACHE_HOME or $HOME/.cache. We can't easily
	// distinguish, but check that if XDG_CACHE_HOME is unset, the dir
	// ends with ".cache".
	var xdg string = os.Getenv("XDG_CACHE_HOME")
	if len(xdg) == 0 {
		if strings.HasSuffix(dir, "/.cache") { pass = pass + 1 }
	} else {
		// If XDG_CACHE_HOME is set, the dir should equal it.
		if dir == xdg { pass = pass + 1 }
	}

	// Result is an absolute path on Linux (starts with `/`).
	if dir[0] == 47 { pass = pass + 1 }

	// Compare to UserConfigDir — same HOME base, different suffix.
	var cfg string = ""
	var cerr error = nil
	cfg, cerr = os.UserConfigDir()
	if cerr == nil { pass = pass + 1 }
	// Both end with appropriate `.cache` / `.config` suffixes when
	// XDG vars are unset; if set we just verify both succeed.
	if len(cfg) > 0 { pass = pass + 1 }

	log.Println("pass=%d", pass)
	if pass == 6 { ret 42 }
	ret 0
}
