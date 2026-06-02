package main
import "log"
import "os"
import "crypto/rand"
import "strings"

fun main() int {
	var pass int = 0

	// Use a random-suffixed test root so this is reusable.
	var suffix string = rand.AlphanumString(12)
	var tmp string = "/tmp/volt_mkdirall_" + suffix
	var nested string = tmp + "/a/b/c/d"

	// Pre-condition: neither exists.
	if !os.Exists(tmp) { pass = pass + 1 }
	if !os.Exists(nested) { pass = pass + 1 }

	// MkdirAll — happy path.
	var r1 int = os.MkdirAll(nested, 493)   // 0o755
	if r1 == 0 { pass = pass + 1 }
	if os.Exists(tmp) { pass = pass + 1 }
	if os.Exists(tmp + "/a") { pass = pass + 1 }
	if os.Exists(tmp + "/a/b") { pass = pass + 1 }
	if os.Exists(tmp + "/a/b/c") { pass = pass + 1 }
	if os.Exists(nested) { pass = pass + 1 }

	// MkdirAll — idempotent (re-call on existing path is no-op).
	var r2 int = os.MkdirAll(nested, 493)
	if r2 == 0 { pass = pass + 1 }

	// MkdirAll — empty path → 0 (no-op).
	if os.MkdirAll("", 493) == 0 { pass = pass + 1 }

	// MkdirAll — root "/" already exists.
	if os.MkdirAll("/", 493) == 0 { pass = pass + 1 }

	// MkdirAll — path ending with trailing slash.
	var slashed string = tmp + "/e/f/"
	var r3 int = os.MkdirAll(slashed, 493)
	if r3 == 0 { pass = pass + 1 }
	if os.Exists(tmp + "/e/f") { pass = pass + 1 }

	// MkdirAll — single segment under existing parent.
	var single string = tmp + "/g"
	var r4 int = os.MkdirAll(single, 493)
	if r4 == 0 { pass = pass + 1 }
	if os.Exists(single) { pass = pass + 1 }

	// Cleanup — remove deepest first.
	os.Remove(nested)
	os.Remove(tmp + "/a/b/c")
	os.Remove(tmp + "/a/b")
	os.Remove(tmp + "/a")
	os.Remove(tmp + "/e/f")
	os.Remove(tmp + "/e")
	os.Remove(tmp + "/g")
	os.Remove(tmp)

	if !strings.HasPrefix("anything", "no") { pass = pass + 1 }   // sanity-shim

	log.Println("pass=%d", pass)
	if pass == 16 { ret 42 }
	ret 0
}
