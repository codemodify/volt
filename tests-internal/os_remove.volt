// os.Remove smoke — exercises both the file and empty-directory
// paths (the runtime's EISDIR-retry-with-AT_REMOVEDIR logic).

package main

import "os"
import "time"
import "strconv"
import "log"

fun main() int {
    var pass int = 0

    var stamp int = time.Mono()

    // ---- Remove a directory ----------------------------------------
    var dir string = "/tmp/volt_rm_" + strconv.Itoa(stamp)
    if os.Mkdir(dir, 493) != 0 { ret 0 }    // setup failed
    if os.Exists(dir) { pass = pass + 1 }
    if os.Remove(dir) == 0 { pass = pass + 1 }
    if !os.Exists(dir) { pass = pass + 1 }

    // ---- Remove a file ---------------------------------------------
    var path string = "/tmp/volt_rmf_" + strconv.Itoa(stamp)
    var f os.File = new os.File{}
    var err error = nil
    f, err = os.Create(path)
    if err != nil { ret 0 }
    var nWrote int = 0
    nWrote, err = f.Write("hi")
    if nWrote == 2 { pass = pass + 1 }
    f.Close()
    if os.Exists(path) { pass = pass + 1 }
    if os.Remove(path) == 0 { pass = pass + 1 }
    if !os.Exists(path) { pass = pass + 1 }

    // ---- Remove non-existent path → error ---------------------------
    if os.Remove("/no/such/path") != 0 { pass = pass + 1 }

    // ---- Remove non-empty directory → ENOTEMPTY ---------------------
    var ndir string = "/tmp/volt_rm_nempty_" + strconv.Itoa(stamp)
    if os.Mkdir(ndir, 493) != 0 { ret 0 }
    var inner string = ndir + "/file"
    var f2 os.File = new os.File{}
    var ferr error = nil
    f2, ferr = os.Create(inner)
    if ferr != nil { ret 0 }
    f2.Close()
    if os.Remove(ndir) != 0 { pass = pass + 1 }   // can't remove non-empty
    // Clean up the inner file then the now-empty dir.
    if os.Remove(inner) == 0 { pass = pass + 1 }
    if os.Remove(ndir)  == 0 { pass = pass + 1 }

    log.Println("pass=%d/11", pass)
    if pass == 11 { ret 42 }
    ret 0
}
