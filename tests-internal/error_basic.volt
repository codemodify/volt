package main
import "log"

type MyErr struct {
    code int
}

fun (e *MyErr) Error() string {
    ret "my error"
}

fun bad() error {
    var e MyErr = new MyErr{code: 7}
    var err error = e
    ret err
}

fun main() int {
    var e error = bad()
    var msg string = e.Error()
    log.Println(msg)
    ret 42
}
