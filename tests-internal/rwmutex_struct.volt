// rwmutex Snapshot — 1 writer, 2 readers, struct payload.
// Writer bumps version 0..100. Readers observe but don't mutate
// (LockRead binds a read-only guard — field writes would be a
// compile-time error).
// Final version should be 100. Exit 42 = success.

package main

type Snapshot struct {
    version int
    payload int
}

fun writer(s rwmutex Snapshot, done chan int) {
    var i int = 0
    for i < 100 {
        var v Snapshot = s.Lock()       // writer guard
        v.version = v.version + 1
        v.payload = v.version * 2
        i = i + 1
    }
    write(done, 1)
}

fun reader(s rwmutex Snapshot, done chan int) {
    var i int = 0
    var sum int = 0
    for i < 1000 {
        var v Snapshot = s.LockRead()   // reader guard — fields are read-only
        sum = sum + v.version + v.payload
        i = i + 1
    }
    write(done, 1)
}

fun main() int {
    var s rwmutex Snapshot = new{version: 0, payload: 0}
    var done chan int = new(3) chan int
    run writer(s, done)
    run reader(s, done)
    run reader(s, done)
    read(done)
    read(done)
    read(done)
    var snap Snapshot = s.LockRead()
    if snap.version == 100 {
        ret 42
    }
    ret 0
}
