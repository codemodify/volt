// atomic int32 — same semantics as atomic int but storage is 4 bytes.
// Two threads each Add(1) 1000 times. Final should be 2000. Exit 42 = ok.

package main

fun bumper(a atomic int32, done chan int) {
    var i int = 0
    for i < 1000 {
        a.Add(1)
        i = i + 1
    }
    write(done, 1)
}

fun main() int {
    var a atomic int32 = new{}
    var done chan int = new(2) chan int
    run bumper(a, done)
    run bumper(a, done)
    read(done)
    read(done)
    var n int32 = a.Load()
    if n == 2000 {
        ret 42
    }
    ret 0
}
