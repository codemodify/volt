// automatic Drop() on owned struct values at scope exit.
// Main creates two Resources; both their Drop() methods fire (LIFO).

package main

import "log"

type Resource struct {
    id int
}

fun (r *Resource) Drop() {
    log.Println("Drop")
}

fun main() int {
    var a Resource = new Resource{id: 1}
    var b Resource = new Resource{id: 2}
    ret a.id + b.id + 39   // 1 + 2 + 39 = 42
}
