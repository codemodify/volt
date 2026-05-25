package main
import "log"

fun main() int {
    var o once = new()
    var counter atomic int = new {}
    var wg waitgroup = new()

    for i := 0; i < 10; i++ {
        wg.Add(1)
        run worker(o, counter, wg)
    }
    wg.Wait()

    log.Println("init ran: %d", counter.Read())
    if counter.Read() == 1 { ret 42 }
    ret 0
}

fun worker(o once, c atomic int, wg waitgroup) {
    o.Do(fun() {
        c.Add(1)
    })
    wg.Done()
}
