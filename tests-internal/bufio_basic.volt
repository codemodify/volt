// bufio.Buffer wraps a writer function and accumulates string chunks.
// Flush forwards the accumulated payload to the underlying writer.

package main

import "bufio"
import "log"

fun sinkWrite(s string) (int, error) {
    log.Println("sink got: [%s]", s)
    ret len(s), nil
}

fun main() int {
    var w fun(string) (int, error) = sinkWrite
    var b *Buffer = bufio.New(w)

    b.WriteString("hello, ")
    b.WriteString("world")
    b.WriteString("!")

    var n int = 0
    var err error = nil
    n, err = b.Flush()
    if err != nil { ret 0 }

    log.Println("flushed n=%d", n)
    if n == 13 { ret 42 }
    ret 0
}
