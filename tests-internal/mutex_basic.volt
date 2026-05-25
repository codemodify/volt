// mutex primitive smoke test — two threads each increment a shared
// int counter 1000 times via the guard pattern.
// Final value should be 2000. Exit 42 = success.
//
// Tests:
//   - var m mutex int = new{} (zero-init) or new{5} (initial value)
//   - passing mutex handle to a goroutine (reference-typed)
//   - var v int = m.Lock() acquires + binds a guard
//   - v = v + 1 writes through the guard into the mutex's storage
//   - guard auto-releases at end of each loop iteration

package main

fun bumper(m mutex int, done chan int) {
    var i int = 0
    for i < 1000 {
        var v int = m.Lock()
        v = v + 1
        i = i + 1
    }
    write(done, 1)
}

fun main() int {
    var m mutex int = new{}
    var done chan int = new(2) chan int
    run bumper(m, done)
    run bumper(m, done)
    read(done)
    read(done)
    var final int = m.Lock()
    if final == 2000 {
        ret 42
    }
    ret 0
}
