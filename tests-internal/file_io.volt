// Raw file I/O via syscall package: open, write, close, reopen, read.
// Verifies the volt_open / volt_close / volt_write_n / volt_read_all
// runtime entry points work end-to-end with the codegen intrinsics.
//
// Note: os.File (Drop-auto-close ergonomic wrapper) is designed but
// blocked on cross-package method dispatch — see TODO.md.

package main

import "log"
import "syscall"

fun main() int {
    var path string = "/tmp/volt_a6_file_io.txt"
    // O_WRONLY | O_CREAT | O_TRUNC = 1 | 0x40 | 0x200 = 577
    var fd int = syscall.Open(path, 577, 0644)
    if fd < 0 {
        log.Println("open(write) failed: %d", fd)
        ret 0
    }
    var msg string = "volt file I/O works\n"
    var n int = syscall.WriteAll(fd, msg)
    if n < 0 {
        log.Println("write failed: %d", n)
        syscall.Close(fd)
        ret 0
    }
    log.Println("wrote %d bytes", n)
    syscall.Close(fd)

    var rfd int = syscall.Open(path, 0, 0)
    if rfd < 0 {
        log.Println("open(read) failed: %d", rfd)
        ret 0
    }
    var got string = syscall.ReadAll(rfd)
    syscall.Close(rfd)
    log.Println("read=%s", got)
    log.Println("len=%d", len(got))
    if len(got) == 20 { ret 42 }
    ret 0
}
