package main

import "log"
import "errors"

fun main() int {
    var ErrTooBig error = errors.New("value too big")
    var ErrTooSmall error = errors.New("value too small")

    var pass int = 0
    var e error = ErrTooBig
    log.Println("first: %s", e.Error())
    if e == ErrTooBig { pass = pass + 1 }
    if e != ErrTooSmall { pass = pass + 1 }

    var e2 error = ErrTooSmall
    log.Println("second: %s", e2.Error())
    if e2 == ErrTooSmall { pass = pass + 1 }

    log.Println("pass=%d", pass)
    if pass == 3 { ret 42 }
    ret 0
}
