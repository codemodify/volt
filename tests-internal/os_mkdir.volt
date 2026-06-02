// os.Mkdir + os.Exists smoke. Creates and tests a directory in /tmp,
// confirms Exists is reachable. Doesn't clean up; the tempdir name
// embeds the pid-ish process timestamp to avoid collisions across
// reruns and the kernel reclaims /tmp eventually.

package main

import "os"
import "time"
import "strconv"
import "log"

fun main() int {
    var pass int = 0

    // Pre-existing paths.
    if os.Exists("/tmp")     { pass = pass + 1 }
    if os.Exists("/")        { pass = pass + 1 }
    if !os.Exists("/no/such/path") { pass = pass + 1 }

    // Fresh directory.
    var stamp int = time.Mono()
    var dir string = "/tmp/volt_mkdir_" + strconv.Itoa(stamp)
    if !os.Exists(dir) { pass = pass + 1 }
    var rc int = os.Mkdir(dir, 493)   // 0o755 = 493 decimal
    if rc == 0 { pass = pass + 1 }
    if os.Exists(dir) { pass = pass + 1 }

    // Mkdir same path again: -17 = -EEXIST.
    var rc2 int = os.Mkdir(dir, 493)
    if rc2 != 0 { pass = pass + 1 }

    // Mkdir under a non-existent parent: -2 = -ENOENT.
    var rc3 int = os.Mkdir("/no/such/parent/sub", 493)
    if rc3 != 0 { pass = pass + 1 }

    log.Println("pass=%d/8", pass)
    if pass == 8 { ret 42 }
    ret 0
}
