// rwmutex primitive smoke test — one writer thread, two reader threads.
// Writer increments value 0..100. Each reader does 1000 reads.
// Final value should be 100. Exit 42 = success.
//
// Tests:
//   - var r rwmutex int = new{} (zero-init) or new{5} (initial value)
//   - var v int = r.Lock()       — writer guard, exclusive, auto-releases
//   - var v int = r.LockRead()   — reader guard, read-only, parallel-safe

package main

fun writer(r rwmutex int, done chan int) {
    var i int = 0
    for i < 100 {
        var v int = r.Lock()      // writer guard
        v = v + 1                 // exclusive write through the guard
        i = i + 1
    }                             // guard drops → exclusive lock released
    write(done, 1)
}

fun reader(r rwmutex int, done chan int) {
    var i int = 0
    var sum int = 0
    for i < 1000 {
        var v int = r.LockRead()  // reader guard — read-only
        sum = sum + v
        i = i + 1
    }                             // reader guard drops → read lock released
    write(done, 1)
}

fun main() int {
    var r rwmutex int = new{}
    var done chan int = new(3) chan int
    run writer(r, done)
    run reader(r, done)
    run reader(r, done)
    read(done)
    read(done)
    read(done)
    var final int = r.LockRead()
    if final == 100 {
        ret 42
    }
    ret 0
}
