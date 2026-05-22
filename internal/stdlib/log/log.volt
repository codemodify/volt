// Package log: minimal logger.
//
// v0.3 surface:
//   Println(s string)   write s + "\n" to stderr

package log

import "syscall"

fun Println(s string) {
    syscall.Write(2, s)
    syscall.Write(2, "\n")
}
