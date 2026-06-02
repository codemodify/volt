// os.ReadFile + os.WriteFile end-to-end round-trip + error paths.

package main

import "os"
import "time"
import "strconv"
import "log"

fun main() int {
    var pass int = 0
    var stamp int = time.Mono()
    var path string = "/tmp/volt_rwfile_" + strconv.Itoa(stamp)

    // WriteFile: fresh file.
    var werr error = os.WriteFile(path, "hello\nworld\n", 420)   // 0644 = 420
    if werr == nil { pass = pass + 1 }
    if os.Exists(path) { pass = pass + 1 }

    // ReadFile round-trips the bytes.
    var data string = ""
    var rerr error = nil
    data, rerr = os.ReadFile(path)
    if rerr == nil { pass = pass + 1 }
    if data == "hello\nworld\n" { pass = pass + 1 }
    if len(data) == 12 { pass = pass + 1 }

    // Overwrite — WriteFile truncates.
    var werr2 error = os.WriteFile(path, "shorter", 420)
    if werr2 == nil { pass = pass + 1 }
    var data2 string = ""
    var rerr2 error = nil
    data2, rerr2 = os.ReadFile(path)
    if rerr2 == nil { pass = pass + 1 }
    if data2 == "shorter" { pass = pass + 1 }

    // Empty content.
    var werr3 error = os.WriteFile(path, "", 420)
    if werr3 == nil { pass = pass + 1 }
    var data3 string = ""
    var rerr3 error = nil
    data3, rerr3 = os.ReadFile(path)
    if rerr3 == nil { if data3 == "" { pass = pass + 1 } }

    // ReadFile on missing path errors.
    var missing string = ""
    var merr error = nil
    missing, merr = os.ReadFile("/no/such/path")
    if merr != nil { pass = pass + 1 }
    if missing == "" { pass = pass + 1 }

    // Cleanup.
    os.Remove(path)

    log.Println("pass=%d/12", pass)
    if pass == 12 { ret 42 }
    ret 0
}
