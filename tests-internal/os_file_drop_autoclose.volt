// os_file_drop_autoclose — POSITIVE.
//
// File.Close/Drop are pointer receivers, so `closed` persists: an explicit
// Close followed by the scope-end Drop does NOT double-close, and a file
// left unclosed IS closed by Drop (fds don't leak). The 1500-file loop would
// exhaust the ~1024 fd limit if Drop weren't actually closing each one.

package main

import "os"
import "log"

fun main() int {
    var path string = os.TempDir() + "/volt-fdtest"

    // explicit Close, then scope-end Drop — must not double-close
    {
        var f os.File = new os.File{}
        var err error = nil
        f, err = os.Create(path)
        if err != nil { ret 1 }
        var cerr error = f.Close()
        if cerr != nil { ret 2 }
    }

    // 1500 files left unclosed — Drop closes each at loop-body scope end
    var i int = 0
    for i = 0; i < 1500; i++ {
        var f os.File = new os.File{}
        var err error = nil
        f, err = os.Create(path)
        if err != nil {
            log.Println("fd exhaustion at i=%d — Drop not closing", i)
            ret 3
        }
    }
    os.Remove(path)
    log.Println("file Drop auto-close OK (no double-close, no fd leak)")
    ret 42
}
