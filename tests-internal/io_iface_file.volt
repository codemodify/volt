// io.Writer interface satisfied by os.File (cross-package, value
// receiver). Exercises the synthesized _$iface trampolines: vtable
// passes ptr, but os.File.Write has a value receiver, so the
// trampoline loads %File from the ptr before forwarding.

package main

import "io"
import "os"
import "log"

fun writeMsg(w Writer, msg string) (int, error) {
    var n int = 0
    var err error = nil
    n, err = w.Write(msg)
    ret n, err
}

fun main() int {
    var path string = "/tmp/volt_io_file_iface_test.txt"

    f, oerr := os.Create(path)
    if oerr != nil {
        log.Println("create failed: %s", oerr.Error())
        ret 0
    }

    var n int = 0
    var werr error = nil
    n, werr = writeMsg(f, "hello via io.Writer\n")
    if werr != nil {
        log.Println("write failed: %s", werr.Error())
        ret 0
    }
    log.Println("wrote %d bytes", n)
    f.Close()

    if n == 20 { ret 42 }
    ret 0
}
