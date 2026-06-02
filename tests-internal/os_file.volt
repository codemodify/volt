// os.File ergonomic file I/O: Create / Write / Close / Open / Read.
// Cross-package method dispatch — methods on `File` defined in
// package os, called from package main.

package main

import "log"
import "os"

fun main() int {
    var path string = "/tmp/volt_os_file_test.txt"

    f, err := os.Create(path)
    if err != nil {
        log.Println("create failed: %s", err.Error())
        ret 0
    }
    n, werr := f.Write("through os.File\n")
    if werr != nil {
        log.Println("write failed: %s", werr.Error())
        ret 0
    }
    log.Println("wrote %d bytes", n)
    f.Close()

    g, err2 := os.Open(path)
    if err2 != nil {
        log.Println("open failed: %s", err2.Error())
        ret 0
    }
    s, rerr := g.Read()
    if rerr != nil {
        log.Println("read failed: %s", rerr.Error())
        ret 0
    }
    log.Println("read back: %s", s)
    g.Close()

    if len(s) == 16 { ret 42 }
    ret 0
}
