package main
import "log"
import "os"
import "strings"

// Positive test: os.UserHomeDir / os.UserConfigDir. Verifies $HOME-
// based resolution and the $XDG_CONFIG_HOME fallback. Test runs in a
// standard Linux environment where $HOME is always set.

fun main() int {
	var pass int = 0

	var h string = ""
	var e error = nil
	h, e = os.UserHomeDir()
	if e == nil { pass = pass + 1 }
	// $HOME should be a non-empty absolute path.
	if len(h) > 0 { pass = pass + 1 }
	if strings.HasPrefix(h, "/") { pass = pass + 1 }

	var c string = ""
	var e2 error = nil
	c, e2 = os.UserConfigDir()
	if e2 == nil { pass = pass + 1 }
	if len(c) > 0 { pass = pass + 1 }
	// Either matches $XDG_CONFIG_HOME or ends with /.config.
	var xdg string = os.Getenv("XDG_CONFIG_HOME")
	if len(xdg) > 0 {
		if c == xdg { pass = pass + 1 }
	} else {
		if strings.HasSuffix(c, "/.config") { pass = pass + 1 }
	}

	log.Println("home=%s cfg=%s pass=%d", h, c, pass)
	if pass == 6 { ret 42 }
	ret 0
}
