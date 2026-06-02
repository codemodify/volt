// net package — TCP loopback round-trip in a single process.
// Server: spawned via `run`, accepts one client, reads bytes until
// peer closes, signals the result back through a channel.
// Client: dials, writes a message, closes (half-close-by-close), then
// the main thread reads what the server got off the channel.

package main

import "net"
import "time"
import "log"

fun serverSide(l Listener, ch chan write string) {
    var c Conn = new Conn {fd: -1, closed: true}
    var aerr error = nil
    c, aerr = l.Accept()
    if aerr != nil {
        write(ch, "ACCEPT_FAIL")
        ret
    }
    var got string = ""
    var rerr error = nil
    got, rerr = c.Read()
    if rerr != nil {
        write(ch, "READ_FAIL")
        ret
    }
    c.Close()
    write(ch, got)
}

fun main() int {
    var l Listener = new Listener {fd: -1, closed: true}
    var lerr error = nil
    l, lerr = net.Listen("127.0.0.1:18765")
    if lerr != nil {
        log.Println("listen failed: %s", lerr.Error())
        ret 0
    }

    var ch chan11 string = new()
    run serverSide(l, ch)

    // Give the accept thread a moment to enter sys_accept.
    time.Sleep(50 * 1000000)

    var c Conn = new Conn {fd: -1, closed: true}
    var derr error = nil
    c, derr = net.Dial("127.0.0.1:18765")
    if derr != nil {
        log.Println("dial failed: %s", derr.Error())
        ret 0
    }

    var n int = 0
    var werr error = nil
    n, werr = c.Write("hello tcp\n")
    if werr != nil {
        log.Println("write failed: %s", werr.Error())
        ret 0
    }
    if n != 10 {
        log.Println("short write: %d", n)
        ret 0
    }
    c.Close()

    var got string = read(ch)
    l.Close()

    log.Println("server got: [%s]", got)
    if got == "hello tcp\n" { ret 42 }
    ret 0
}
